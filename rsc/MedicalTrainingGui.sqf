// =============================================================================
// MedicalTrainingGui.sqf  -  medical training dummies (client; ACE + KAM assumed)
// terminalMedical addAction. Server: FADE_medTrain_* in initServer.sqf
// Single layout: dummy list (left) + injury controls (right); no tabs.
// =============================================================================

FAC_medicalTrainingGui_applyLayout = {
    private _d = findDisplay 60800;
    if (isNull _d) exitWith {};
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow false } } forEach [60890, 60891];
    private _injuryIdcs = [
        60892, 60802, 60830, 60836, 60894, 60895, 60896, 60897, 60898, 60899, 60900, 60901, 60902, 60903, 60904, 60905,
        60860, 60861, 60862, 60863, 60871, 60864, 60872, 60865, 60866, 60867, 60868, 60869, 60870,
        60803, 60804, 60806, 60805, 60807, 60831, 60832, 60833, 60834, 60835, 60850
    ];
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow true } } forEach _injuryIdcs;
    private _set = {
        params ["_idc", "_x", "_y", "_w", "_h"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then { _c ctrlSetPosition [_x, _y, _w, _h]; _c ctrlCommit 0 };
    };
    [60880, 0.04, 0.105, 0.28, 0.028] call _set;
    [60801, 0.04, 0.135, 0.28, 0.52] call _set;
    [60814, 0.04, 0.665, 0.28, 0.036] call _set;
    [60815, 0.04, 0.708, 0.28, 0.036] call _set;
    [60816, 0.04, 0.751, 0.28, 0.036] call _set;
    [60893, 0.04, 0.794, 0.28, 0.048] call _set;
    [60892, 0.34, 0.105, 0.62, 0.028] call _set;
    [60802, 0.34, 0.132, 0.62, 0.034] call _set;
    [60830, 0.34, 0.172, 0.30, 0.036] call _set;
    [60836, 0.66, 0.172, 0.32, 0.036] call _set;
    [60894, 0.34, 0.216, 0.62, 0.022] call _set;
    [60895, 0.34, 0.240, 0.30, 0.018] call _set;
    [60860, 0.34, 0.260, 0.30, 0.032] call _set;
    [60896, 0.66, 0.240, 0.30, 0.018] call _set;
    [60861, 0.66, 0.260, 0.30, 0.032] call _set;
    [60897, 0.34, 0.298, 0.30, 0.018] call _set;
    [60862, 0.34, 0.318, 0.30, 0.032] call _set;
    [60898, 0.66, 0.298, 0.30, 0.018] call _set;
    [60863, 0.66, 0.318, 0.30, 0.032] call _set;
    [60871, 0.34, 0.356, 0.62, 0.018] call _set;
    [60864, 0.34, 0.376, 0.62, 0.028] call _set;
    [60872, 0.34, 0.410, 0.62, 0.018] call _set;
    [60865, 0.34, 0.430, 0.62, 0.028] call _set;
    [60899, 0.34, 0.464, 0.30, 0.018] call _set;
    [60866, 0.34, 0.484, 0.30, 0.032] call _set;
    [60900, 0.66, 0.464, 0.30, 0.018] call _set;
    [60867, 0.66, 0.484, 0.30, 0.032] call _set;
    [60868, 0.34, 0.524, 0.62, 0.036] call _set;
    [60901, 0.34, 0.568, 0.62, 0.022] call _set;
    [60869, 0.34, 0.592, 0.44, 0.034] call _set;
    [60870, 0.80, 0.592, 0.16, 0.034] call _set;
    [60902, 0.34, 0.634, 0.62, 0.022] call _set;
    [60903, 0.34, 0.658, 0.30, 0.018] call _set;
    [60803, 0.34, 0.678, 0.30, 0.032] call _set;
    [60904, 0.66, 0.658, 0.30, 0.018] call _set;
    [60804, 0.66, 0.678, 0.30, 0.032] call _set;
    [60806, 0.34, 0.716, 0.62, 0.018] call _set;
    [60805, 0.34, 0.736, 0.62, 0.028] call _set;
    [60905, 0.34, 0.770, 0.30, 0.018] call _set;
    [60807, 0.34, 0.790, 0.30, 0.032] call _set;
    [60831, 0.66, 0.770, 0.30, 0.052] call _set;
    [60832, 0.34, 0.832, 0.30, 0.036] call _set;
    [60833, 0.66, 0.832, 0.30, 0.036] call _set;
    [60834, 0.34, 0.876, 0.30, 0.036] call _set;
    [60835, 0.66, 0.876, 0.30, 0.036] call _set;
    [60850, 0.34, 0.920, 0.62, 0.028] call _set;
    private _legacyLabels = [
        "Airway / chest (Zeus parity)", "Obstruction", "Occluded", "Hemopneumothorax", "Tension PTX",
        "PTX deteriorate", "Deep penetrating", "Cardiac rhythm", "Bleeding wound / part", "Body part", "Wound type", "Depth"
    ];
    private _legacyHidden = 0;
    {
        if ((ctrlIDC _x) == -1 && { (ctrlText _x) in _legacyLabels }) then {
            _x ctrlShow false;
            // #region agent log
            _legacyHidden = _legacyHidden + 1;
            // #endregion
        };
    } forEach (allControls _d);
    // #region agent log
    private _labelIdcs = [60894, 60895, 60896, 60897, 60898, 60899, 60900, 60901, 60902, 60903, 60904, 60905];
    private _missing = [];
    private _presentShown = [];
    private _presentHidden = [];
    {
        private _c = _d displayCtrl _x;
        if (isNull _c) then {
            _missing pushBack _x;
        } else {
            if (ctrlShown _c) then { _presentShown pushBack [_x, ctrlText _c] } else { _presentHidden pushBack [_x, ctrlText _c] };
        };
    } forEach _labelIdcs;
    private _comboIdcs = [60860, 60861, 60862, 60863, 60869, 60803, 60804, 60807];
    private _combosOk = [];
    { private _c = _d displayCtrl _x; _combosOk pushBack [_x, !isNull _c, if (isNull _c) then { false } else { ctrlShown _c }] } forEach _comboIdcs;
    diag_log format ["FAC_DEBUG_ca734f {""sessionId"":""ca734f"",""hypothesisId"":""A"",""location"":""MedicalTrainingGui.sqf:applyLayout"",""message"":""missing_label_idcs"",""data"":{""missing"":%1,""presentShown"":%2,""presentHidden"":%3},""timestamp"":%4}", _missing, _presentShown, _presentHidden, floor (time * 1000)];
    diag_log format ["FAC_DEBUG_ca734f {""sessionId"":""ca734f"",""hypothesisId"":""B"",""location"":""MedicalTrainingGui.sqf:applyLayout"",""message"":""legacy_labels_hidden"",""data"":{""legacyHiddenCount"":%1},""timestamp"":%2}", _legacyHidden, floor (time * 1000)];
    diag_log format ["FAC_DEBUG_ca734f {""sessionId"":""ca734f"",""hypothesisId"":""C"",""location"":""MedicalTrainingGui.sqf:applyLayout"",""message"":""combo_visibility"",""data"":{""combos"":%1},""timestamp"":%2}", _combosOk, floor (time * 1000)];
    missionNamespace setVariable ["FAC_DEBUG_medTrainLabels", [_missing, _legacyHidden, _presentShown, _presentHidden]];
    systemChat format ["FAC_DEBUG med labels missing=%1 legacyHidden=%2", count _missing, _legacyHidden];
    // #endregion
};

FAC_medicalTrainingGui_fnc = {
    params ["_action", "_params"];

    private _fncSelNetId = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { "" };
        private _lb = _display displayCtrl 60801;
        private _i = lbCurSel _lb;
        if (_i < 0) exitWith { "" };
        _lb lbData _i
    };

    private _fncPresetKey = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { "" };
        private _cb = _display displayCtrl 60802;
        private _i = lbCurSel _cb;
        if (_i < 0) exitWith { "" };
        _cb lbData _i
    };

    private _fncBodyKey = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { "body" };
        private _cb = _display displayCtrl 60803;
        private _i = lbCurSel _cb;
        if (_i < 0) exitWith { "body" };
        _cb lbData _i
    };

    private _fncWoundType = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { "Laceration" };
        private _cb = _display displayCtrl 60804;
        private _i = lbCurSel _cb;
        if (_i < 0) exitWith { "Laceration" };
        _cb lbText _i
    };

    private _fncDepth = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { 2 };
        private _cb = _display displayCtrl 60807;
        private _i = lbCurSel _cb;
        if (_i < 0) exitWith { 2 };
        parseNumber (_cb lbData _i)
    };

    private _fncBleedFromSlider = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith { 0.35 };
        private _sl = _display displayCtrl 60805;
        private _p = sliderPosition _sl;
        0.05 + (_p / 100) * 1.15
    };

    private _fncRefreshDummyList = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith {};
        private _lb = _display displayCtrl 60801;
        private _sel = lbCurSel _lb;
        private _keep = if (_sel >= 0 && {_sel < lbSize _lb}) then { _lb lbData _sel } else { "" };
        lbClear _lb;
        private _rows = missionNamespace getVariable ["FAC_medTrain_clientList", []];
        {
            _x params ["_nid", "_alive", "_idx"];
            private _row = _lb lbAdd format ["Dummy %1  -  %2", (_idx + 1), (if (_alive) then { "alive" } else { "dead" })];
            _lb lbSetData [_row, _nid];
        } forEach _rows;
        if (lbSize _lb > 0) then {
            private _newSel = 0;
            if (_keep != "") then {
                private _fi = -1;
                for "_j" from 0 to ((lbSize _lb) - 1) do {
                    if ((_lb lbData _j) == _keep) exitWith { _fi = _j };
                };
                if (_fi >= 0) then { _newSel = _fi };
            };
            _lb lbSetCurSel _newSel;
        };
        [] call _fncUpdateSelectedTarget;
    };

    private _fncUpdateSelectedTarget = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith {};
        private _lb = _display displayCtrl 60801;
        private _tgt = _display displayCtrl 60893;
        private _hdr = _display displayCtrl 60880;
        private _i = lbCurSel _lb;
        private _line = if (_i < 0 || { lbSize _lb < 1 }) then {
            "Target: (none — select a dummy)"
        } else {
            format ["Target: %1", _lb lbText _i]
        };
        if (!isNull _tgt) then {
            _tgt ctrlSetText _line;
            if (_i < 0) then {
                _tgt ctrlSetTextColor [0.72, 0.76, 0.82, 1];
            } else {
                _tgt ctrlSetTextColor [1, 0.92, 0.55, 1];
            };
        };
        if (!isNull _hdr) then {
            if (_i < 0) then {
                _hdr ctrlSetText "Training dummies";
            } else {
                _hdr ctrlSetText format ["Training dummies — %1", _lb lbText _i];
            };
        };
    };

    private _fncOffOnCombo = {
        params ["_idc"];
        private _c = (findDisplay 60800) displayCtrl _idc;
        lbClear _c;
        private _r0 = _c lbAdd "Off";
        _c lbSetData [_r0, "0"];
        private _r1 = _c lbAdd "On";
        _c lbSetData [_r1, "1"];
        _c lbSetCurSel 0;
    };

    private _fncComboDataNum = {
        params ["_idc", ["_default", 0]];
        private _d = findDisplay 60800;
        if (isNull _d) exitWith { _default };
        private _c = _d displayCtrl _idc;
        private _i = lbCurSel _c;
        if (_i < 0) exitWith { _default };
        parseNumber (_c lbData _i)
    };

    private _fncFillAirwayChestCombos = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith {};
        [60860] call _fncOffOnCombo;
        [60861] call _fncOffOnCombo;
        [60862] call _fncOffOnCombo;
        [60863] call _fncOffOnCombo;
        [60866] call _fncOffOnCombo;
        [60867] call _fncOffOnCombo;
        private _card = _display displayCtrl 60869;
        lbClear _card;
        {
            _x params ["_k", "_lbl"];
            private _r = _card lbAdd _lbl;
            _card lbSetData [_r, str _k];
        } forEach [
            [0, "Normal (no arrest)"],
            [1, "Asystole"],
            [2, "PEA"],
            [3, "VF"],
            [4, "VT"]
        ];
        _card lbSetCurSel 0;
        private _ptx = _display displayCtrl 60864;
        _ptx sliderSetRange [0, 4];
        _ptx sliderSetPosition 0;
        private _sp = _display displayCtrl 60865;
        _sp sliderSetRange [0, 100];
        _sp sliderSetPosition 90;
    };

    private _fncUpdateKatPtxLabel = {
        private _d = findDisplay 60800;
        if (isNull _d) exitWith {};
        private _v = round (sliderPosition (_d displayCtrl 60864));
        (_d displayCtrl 60871) ctrlSetText format ["Pneumothorax: %1 (0-4)", _v];
    };

    private _fncUpdateKatSpo2Label = {
        private _d = findDisplay 60800;
        if (isNull _d) exitWith {};
        private _v = round (sliderPosition (_d displayCtrl 60865));
        (_d displayCtrl 60872) ctrlSetText format ["SpO2 / PaO2 slot: %1 (0-100)", _v];
    };

    private _fncFillCombos = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith {};
        private _preset = _display displayCtrl 60802;
        lbClear _preset;
        private _sc = missionNamespace getVariable ["FAC_medKAT_scenarioList", []];
        if ((count _sc) == 0) then {
            _sc = [
                ["minor_bleed", "Minor bleed"],
                ["moderate_bleed", "Moderate bleed"],
                ["massive_bleed", "Massive bleed"],
                ["catastrophic_bleed", "Catastrophic bleed"],
                ["airway_obstruction", "Airway obstruction"],
                ["airway_occlusion", "Airway occlusion"],
                ["airway_vomit", "Airway (vomit / occlusion)"],
                ["bloodloss", "Hypovolemia (blood loss)"],
                ["deep_penetrating", "Deep penetrating chest"],
                ["cardiac_vt", "Cardiac  -  VT"],
                ["cardiac_vf", "Cardiac  -  VF"],
                ["cardiac_pea", "Cardiac  -  PEA"],
                ["cardiac_asystole", "Cardiac  -  Asystole"],
                ["fracture_simple", "Fracture  -  simple (random part)"],
                ["fracture_compound", "Fracture  -  compound (random part)"],
                ["fracture_comminuted", "Fracture  -  comminuted (random part)"]
            ];
        };
        {
            _x params ["_key", "_label"];
            private _r = _preset lbAdd _label;
            _preset lbSetData [_r, _key];
        } forEach _sc;
        if (lbSize _preset > 0) then { _preset lbSetCurSel 0 };

        private _body = _display displayCtrl 60803;
        lbClear _body;
        private _bRows = [
            ["head", "Head"],
            ["body", "Body (torso)"],
            ["leftarm", "Left arm"],
            ["rightarm", "Right arm"],
            ["leftleg", "Left leg"],
            ["rightleg", "Right leg"]
        ];
        { private _r = _body lbAdd (_x select 1); _body lbSetData [_r, (_x select 0)] } forEach _bRows;
        _body lbSetCurSel 0;

        private _w = _display displayCtrl 60804;
        lbClear _w;
        { private _r = _w lbAdd _x } forEach ["Laceration", "VelocityWound", "Avulsion"];
        _w lbSetCurSel 0;

        private _d = _display displayCtrl 60807;
        lbClear _d;
        { private _r = _d lbAdd format ["Depth %1", _x]; _d lbSetData [_r, str _x] } forEach [1, 2, 3];
        _d lbSetCurSel 1;
    };

    private _fncUpdateBleedLabel = {
        private _display = findDisplay 60800;
        if (isNull _display) exitWith {};
        private _b = [] call _fncBleedFromSlider;
        (_display displayCtrl 60806) ctrlSetText format ["Bleed rate: %1", (round (_b * 100)) / 100];
    };

    if (_action != "open") then {
        if (isNull (findDisplay 60800)) exitWith {};
    };

    switch _action do {
        case "open": {
            private _ace = isClass (configFile >> "CfgPatches" >> "ace_medical");
            private _kat = isClass (configFile >> "CfgPatches" >> "kat_main");
            if (!_ace || { !_kat }) exitWith {
                systemChat "Medical training requires ACE Medical and KAM (KAT).";
            };
            if (!createDialog "RscDisplayMedicalTraining") then {
                systemChat "MEDICAL TRAINING GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60800;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_medicalTrainingGui_fnc", FAC_medicalTrainingGui_fnc];
            [] call _fncFillCombos;
            [] call _fncFillAirwayChestCombos;
            [] call _fncUpdateKatPtxLabel;
            [] call _fncUpdateKatSpo2Label;
            private _sl = _display displayCtrl 60805;
            _sl sliderSetRange [0, 100];
            _sl sliderSetPosition 30;
            [] call _fncUpdateBleedLabel;
            private _info = format [
                "<t size='0.85' color='%1'>Injuries apply to the <t color='%2'>selected dummy</t> (left). Presets, airway/chest, cardiac, and wounds match Zeus/KAT training tools.</t>",
                FAC_theme_htmlBody, FAC_theme_htmlEmphasis
            ];
            (_display displayCtrl 60850) ctrlSetStructuredText parseText _info;
            [] call FAC_medicalTrainingGui_applyLayout;
            [player] remoteExec ["FADE_medTrain_requestList", 2];
            [] spawn {
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
            [] call _fncUpdateSelectedTarget;
        };
        case "dummySelChanged": {
            [] call _fncUpdateSelectedTarget;
        };
        case "headerRefresh": {
            [player] remoteExec ["FADE_medTrain_requestList", 2];
            [] spawn {
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "refreshListOnly": {
            [] call _fncRefreshDummyList;
        };
        case "bleedSlider": {
            [] call _fncUpdateBleedLabel;
        };
        case "ptxSlider": {
            [] call _fncUpdateKatPtxLabel;
        };
        case "spo2Slider": {
            [] call _fncUpdateKatSpo2Label;
        };
        case "applyPreset": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            private _key = [] call _fncPresetKey;
            if (_key == "") exitWith {};
            [_nid, _key, player] remoteExec ["FADE_medTrain_applyPreset", 2];
            [] spawn {
                sleep 0.2;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "applyRandomPreset": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            private _display = findDisplay 60800;
            if (isNull _display) exitWith {};
            private _cb = _display displayCtrl 60802;
            private _n = lbSize _cb;
            if (_n < 1) exitWith { systemChat "Medical terminal: no presets available." };
            private _ri = floor random _n;
            _cb lbSetCurSel _ri;
            private _key = _cb lbData _ri;
            if (_key == "") exitWith {};
            [_nid, _key, player] remoteExec ["FADE_medTrain_applyPreset", 2];
            [] spawn {
                sleep 0.2;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "applyWound": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            private _bleed = [] call _fncBleedFromSlider;
            private _depth = [] call _fncDepth;
            [_nid, [] call _fncBodyKey, [] call _fncWoundType, _bleed, _depth, player] remoteExec ["FADE_medTrain_applyWound", 2];
        };
        case "applyAirwayChest": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            private _d = findDisplay 60800;
            private _ptx = if (!isNull _d) then { round (sliderPosition (_d displayCtrl 60864)) } else { 0 };
            private _spo2 = if (!isNull _d) then { round (sliderPosition (_d displayCtrl 60865)) } else { 90 };
            [
                _nid,
                [60860] call _fncComboDataNum,
                [60861] call _fncComboDataNum,
                [60862] call _fncComboDataNum,
                [60863] call _fncComboDataNum,
                _ptx,
                _spo2,
                [60866] call _fncComboDataNum,
                [60867] call _fncComboDataNum,
                player
            ] remoteExec ["FADE_medTrain_applyAirwayChest", 2];
        };
        case "applyCardiac": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            private _rhythm = [60869, 0] call _fncComboDataNum;
            [_nid, _rhythm, player] remoteExec ["FADE_medTrain_applyCardiac", 2];
        };
        case "healPart": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            [_nid, [] call _fncBodyKey, player] remoteExec ["FADE_medTrain_healPart", 2];
        };
        case "healAll": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            [_nid, player] remoteExec ["FADE_medTrain_healAll", 2];
            [] spawn {
                sleep 0.25;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "unconscious": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            [_nid, true, player] remoteExec ["FADE_medTrain_setUnconscious", 2];
        };
        case "conscious": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            [_nid, false, player] remoteExec ["FADE_medTrain_setUnconscious", 2];
        };
        case "spawnDummy": {
            [player] remoteExec ["FADE_medTrain_spawn", 2];
            [] spawn {
                sleep 0.35;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "deleteDummy": {
            private _nid = [] call _fncSelNetId;
            if (_nid == "") exitWith { systemChat "Medical terminal: select a dummy." };
            [_nid, player] remoteExec ["FADE_medTrain_delete", 2];
            [] spawn {
                sleep 0.35;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
        case "deleteAll": {
            [player] remoteExec ["FADE_medTrain_deleteAll", 2];
            [] spawn {
                sleep 0.35;
                [player] remoteExec ["FADE_medTrain_requestList", 2];
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
        };
    };
};

true
