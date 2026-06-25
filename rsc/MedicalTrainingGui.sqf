// =============================================================================
// MedicalTrainingGui.sqf  -  medical training dummies (client; ACE + KAM assumed)
// terminalMedical addAction. Server: FADE_medTrain_* in initServer.sqf
// =============================================================================

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
            private _info = "<t color='#a8d4cc'><t color='#FFD700'>Apply airway / chest</t> sets obstruction, occlusion, hemopneumothorax, tension PTX, PTX level, SpO2/PaO2 slot, deterioration, and deep penetrating injury (Zeus <t color='#888'>Manage Airways</t> parity). <t color='#FFD700'>Apply cardiac</t> matches Zeus <t color='#888'>Change Cardiac State</t>.<br/><br/><t color='#FFD700'>Apply preset</t>  -  packaged scenarios (includes KAT Surgery fractures if loaded). <t color='#FFD700'>Apply wound</t>  -  bleeding wound on the selected body part.<br/><br/><t color='#FFD700'>Heal part</t> clears open wounds and KAT fracture on that part. <t color='#FFD700'>Heal all</t> clears KAM breathing/circulation/vitals locals then ACE full heal.</t>";
            (_display displayCtrl 60850) ctrlSetStructuredText parseText _info;
            [player] remoteExec ["FADE_medTrain_requestList", 2];
            [] spawn {
                sleep 0.35;
                ["refreshListOnly", []] call FAC_medicalTrainingGui_fnc;
            };
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
