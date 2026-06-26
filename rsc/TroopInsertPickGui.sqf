// =============================================================================
// TroopInsertPickGui.sqf  -  Troop Insert / Extract: participants + wave slider (60002 overlay)
// =============================================================================
if (hasInterface) then {
    FAC_tiPick_clr_panel = [0.05, 0.06, 0.09, 0.78];
    FAC_tiPick_clr_list = [0.06, 0.08, 0.1, 0.95];
    FAC_tiPick_clr_track = [0.06, 0.08, 0.1, 0.95];
    FAC_tiPick_clr_hdr = [0.85, 0.9, 1, 1];
    FAC_tiPick_clr_val = [0.75, 0.85, 1, 1];
    FAC_tiPick_clr_btn = [0.18, 0.32, 0.48, 1];
    FAC_tiPick_clr_btnAct = [0.22, 0.48, 0.78, 1];
    FAC_tiPick_clr_start = [0.2, 0.45, 0.5, 1];
    FAC_tiPick_clr_cancel = [0.55, 0.12, 0.12, 1];

    FAC_troopInsertPickGui_fnc_destroyOverlay = {
        ["FAC_tiPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };

    FAC_troopInsertPickGui_fnc_missionLabels = {
        params ["_missionType"];
        if (_missionType == "TroopExtract") exitWith {
            ["TROOP EXTRACT", "TROOP EXTRACT", "Extract squads from the field and RTB. Each wave spawns a new pickup near a civ zone."]
        };
        ["TROOP INSERT", "TROOP INSERT", "Insert squads from base to a civ-zone LZ. Each wave spawns fresh squads at base."]
    };

    FAC_troopInsertPickGui_fnc_setWaveSlider = {
        params ["_waves"];
        private _display = findDisplay 60002;
        if (isNull _display) exitWith {};
        _waves = round (_waves max 1 min 10);
        private _sl = _display displayCtrl 60325;
        if (!isNull _sl) then { _sl sliderSetPosition _waves };
        ["refreshWaves", [_waves]] call FAC_troopInsertPickGui_fnc;
    };

    FAC_troopInsertPickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                _params params [["_missionType", "TroopInsert"]];
                if !(_missionType in ["TroopInsert", "TroopExtract"]) then { _missionType = "TroopInsert" };
                if (isNull _display) exitWith {
                    systemChat "TROOP TRANSPORT: open Manage Missions first, then start this mission type.";
                };
                disableSerialization;
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
                [false] call FAC_missionPickOverlay_setBaseVisible;
                private _labels = [_missionType] call FAC_troopInsertPickGui_fnc_missionLabels;
                _labels params ["_titleShort", "_titleBar", "_modeBlurb"];
                private _controls = [];

                private _bg = _display ctrlCreate ["RscText", 60310];
                _bg ctrlSetPosition [0.02, 0.09, 0.96, 0.78];
                _bg ctrlSetBackgroundColor [0.06, 0.07, 0.1, 0.96];
                _bg ctrlCommit 0;
                _controls pushBack _bg;

                private _title = _display ctrlCreate ["RscText", 60311];
                _title ctrlSetPosition [0.02, 0.09, 0.96, 0.048];
                _title ctrlSetText format ["%1  -  PARTICIPATING TRANSPORTS", _titleBar];
                _title ctrlSetBackgroundColor [0.15, 0.28, 0.42, 1];
                _title ctrlCommit 0;
                _controls pushBack _title;

                private _helpPanel = _display ctrlCreate ["RscText", 60326];
                _helpPanel ctrlSetPosition [0.04, 0.145, 0.92, 0.078];
                _helpPanel ctrlSetBackgroundColor FAC_tiPick_clr_panel;
                _helpPanel ctrlCommit 0;
                _controls pushBack _helpPanel;

                private _help = _display ctrlCreate ["RscStructuredText", 60312];
                _help ctrlSetPosition [0.05, 0.152, 0.90, 0.064];
                _help ctrlSetBackgroundColor [0, 0, 0, 0];
                _help ctrlSetStructuredText parseText (
                    "<t size='0.78' color='#B8B8B8'>Pilots/drivers only — one distinct vehicle per participant.</t><br/>" +
                    format ["<t size='0.78' color='#C8D8E8'>%1</t>", _modeBlurb]
                );
                _help ctrlCommit 0;
                _controls pushBack _help;

                private _wavePanel = _display ctrlCreate ["RscText", 60327];
                _wavePanel ctrlSetPosition [0.04, 0.232, 0.92, 0.108];
                _wavePanel ctrlSetBackgroundColor FAC_tiPick_clr_panel;
                _wavePanel ctrlCommit 0;
                _controls pushBack _wavePanel;

                private _waveHdr = _display ctrlCreate ["RscText", 60328];
                _waveHdr ctrlSetPosition [0.05, 0.238, 0.90, 0.026];
                _waveHdr ctrlSetText "WAVES";
                _waveHdr ctrlSetTextColor FAC_tiPick_clr_hdr;
                _waveHdr ctrlCommit 0;
                _controls pushBack _waveHdr;

                private _waveLbl = _display ctrlCreate ["RscText", 60313];
                _waveLbl ctrlSetPosition [0.05, 0.268, 0.34, 0.026];
                _waveLbl ctrlSetText "Number of waves";
                _waveLbl ctrlCommit 0;
                _controls pushBack _waveLbl;

                private _waveVal = _display ctrlCreate ["RscText", 60324];
                _waveVal ctrlSetPosition [0.40, 0.268, 0.54, 0.026];
                _waveVal ctrlSetText "1 wave (single mission)";
                _waveVal ctrlSetTextColor FAC_tiPick_clr_val;
                _waveVal ctrlCommit 0;
                _controls pushBack _waveVal;

                private _waveMin = _display ctrlCreate ["RscText", 60330];
                _waveMin ctrlSetPosition [0.08, 0.302, 0.04, 0.028];
                _waveMin ctrlSetText "1";
                _waveMin ctrlSetTextColor FAC_tiPick_clr_val;
                _waveMin ctrlCommit 0;
                _controls pushBack _waveMin;

                private _waveTrack = _display ctrlCreate ["RscText", 60329];
                _waveTrack ctrlSetPosition [0.12, 0.306, 0.68, 0.022];
                _waveTrack ctrlSetBackgroundColor FAC_tiPick_clr_track;
                _waveTrack ctrlCommit 0;
                _controls pushBack _waveTrack;

                private _waveMax = _display ctrlCreate ["RscText", 60331];
                _waveMax ctrlSetPosition [0.82, 0.302, 0.04, 0.028];
                _waveMax ctrlSetText "10";
                _waveMax ctrlSetTextColor FAC_tiPick_clr_val;
                _waveMax ctrlCommit 0;
                _controls pushBack _waveMax;

                private _waveSlider = _display ctrlCreate ["RscXSliderH", 60325];
                _waveSlider ctrlSetPosition [0.12, 0.298, 0.68, 0.032];
                _waveSlider sliderSetRange [1, 10];
                _waveSlider sliderSetSpeed [1, 1];
                _waveSlider sliderSetPosition 1;
                _waveSlider ctrlCommit 0;
                _waveSlider ctrlAddEventHandler ["SliderPosChanged", {
                    params ["_ctrl"];
                    ["refreshWaves", [sliderPosition _ctrl]] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]);
                }];
                _controls pushBack _waveSlider;

                private _waveDown = _display ctrlCreate ["RscButton", 60332];
                _waveDown ctrlSetPosition [0.05, 0.298, 0.028, 0.032];
                _waveDown ctrlSetText "<";
                _waveDown ctrlSetBackgroundColor FAC_tiPick_clr_btn;
                _waveDown ctrlCommit 0;
                _waveDown ctrlAddEventHandler ["ButtonClick", { ["waveStep", [-1]] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _waveDown;

                private _waveUp = _display ctrlCreate ["RscButton", 60333];
                _waveUp ctrlSetPosition [0.87, 0.298, 0.028, 0.032];
                _waveUp ctrlSetText ">";
                _waveUp ctrlSetBackgroundColor FAC_tiPick_clr_btn;
                _waveUp ctrlCommit 0;
                _waveUp ctrlAddEventHandler ["ButtonClick", { ["waveStep", [1]] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _waveUp;

                private _partPanel = _display ctrlCreate ["RscText", 60334];
                _partPanel ctrlSetPosition [0.04, 0.348, 0.92, 0.395];
                _partPanel ctrlSetBackgroundColor FAC_tiPick_clr_panel;
                _partPanel ctrlCommit 0;
                _controls pushBack _partPanel;

                private _partHdr = _display ctrlCreate ["RscText", 60335];
                _partHdr ctrlSetPosition [0.05, 0.354, 0.90, 0.026];
                _partHdr ctrlSetText "PARTICIPATING TRANSPORTS";
                _partHdr ctrlSetTextColor FAC_tiPick_clr_hdr;
                _partHdr ctrlCommit 0;
                _controls pushBack _partHdr;

                private _la = _display ctrlCreate ["RscText", 60316];
                _la ctrlSetPosition [0.05, 0.386, 0.36, 0.026];
                _la ctrlSetText "Available";
                _la ctrlCommit 0;
                _controls pushBack _la;

                private _ls = _display ctrlCreate ["RscText", 60317];
                _ls ctrlSetPosition [0.59, 0.386, 0.36, 0.026];
                _ls ctrlSetText "Participating";
                _ls ctrlCommit 0;
                _controls pushBack _ls;

                private _lbA = _display ctrlCreate ["RscListbox", 60318];
                _lbA ctrlSetPosition [0.05, 0.416, 0.36, 0.31];
                _lbA ctrlSetBackgroundColor FAC_tiPick_clr_list;
                _lbA ctrlCommit 0;
                _controls pushBack _lbA;

                private _ba = _display ctrlCreate ["RscButton", 60320];
                _ba ctrlSetPosition [0.435, 0.48, 0.13, 0.042];
                _ba ctrlSetText "Add  >>";
                _ba ctrlSetBackgroundColor FAC_tiPick_clr_btnAct;
                _ba ctrlCommit 0;
                _ba ctrlAddEventHandler ["ButtonClick", { ["add", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _ba;

                private _br = _display ctrlCreate ["RscButton", 60321];
                _br ctrlSetPosition [0.435, 0.54, 0.13, 0.042];
                _br ctrlSetText "<<  Remove";
                _br ctrlSetBackgroundColor FAC_tiPick_clr_btn;
                _br ctrlCommit 0;
                _br ctrlAddEventHandler ["ButtonClick", { ["remove", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _br;

                private _lbS = _display ctrlCreate ["RscListbox", 60319];
                _lbS ctrlSetPosition [0.59, 0.416, 0.36, 0.31];
                _lbS ctrlSetBackgroundColor FAC_tiPick_clr_list;
                _lbS ctrlCommit 0;
                _controls pushBack _lbS;

                private _footer = _display ctrlCreate ["RscText", 60336];
                _footer ctrlSetPosition [0.04, 0.752, 0.92, 0.052];
                _footer ctrlSetBackgroundColor [0.04, 0.05, 0.08, 0.85];
                _footer ctrlCommit 0;
                _controls pushBack _footer;

                private _bc = _display ctrlCreate ["RscButton", 60323];
                _bc ctrlSetPosition [0.06, 0.758, 0.18, 0.042];
                _bc ctrlSetText "Cancel";
                _bc ctrlSetBackgroundColor FAC_tiPick_clr_cancel;
                _bc ctrlCommit 0;
                _bc ctrlAddEventHandler ["ButtonClick", { ["close", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bc;

                private _bs = _display ctrlCreate ["RscButton", 60322];
                _bs ctrlSetPosition [0.76, 0.758, 0.18, 0.042];
                _bs ctrlSetText "START";
                _bs ctrlSetBackgroundColor FAC_tiPick_clr_start;
                _bs ctrlCommit 0;
                _bs ctrlAddEventHandler ["ButtonClick", { ["confirm", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bs;

                uinamespace setVariable ["FAC_tiPick_overlayCtrls", _controls];
                uinamespace setVariable ["FAC_tiPick_missionType", _missionType];
                uinamespace setVariable ["FAC_tiPick_selectedUids", [getPlayerUID player]];
                uinamespace setVariable ["FAC_troopInsertPickGui_fnc", FAC_troopInsertPickGui_fnc];
                ["refreshLists", []] call FAC_troopInsertPickGui_fnc;
                ["refreshWaves", [1]] call FAC_troopInsertPickGui_fnc;
            };
            case "waveStep": {
                _params params [["_delta", 0]];
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _sl = _display displayCtrl 60325;
                if (isNull _sl) exitWith {};
                private _next = round ((sliderPosition _sl) + _delta) max 1 min 10;
                [_next] call FAC_troopInsertPickGui_fnc_setWaveSlider;
            };
            case "refreshWaves": {
                _params params [["_pos", 1]];
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _waves = round (_pos max 1 min 10);
                private _val = _display displayCtrl 60324;
                if (!isNull _val) then {
                    private _txt = if (_waves <= 1) then {
                        "1 wave (single mission)"
                    } else {
                        format ["%1 waves (recurring lifts)", _waves]
                    };
                    _val ctrlSetText _txt;
                };
            };
            case "refreshLists": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbA = _display displayCtrl 60318;
                private _lbS = _display displayCtrl 60319;
                if (isNull _lbA || { isNull _lbS }) exitWith {};
                private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
                private _selected = +(uinamespace getVariable ["FAC_tiPick_selectedUids", []]);
                lbClear _lbA;
                lbClear _lbS;
                private _callerUid = getPlayerUID player;
                {
                    if (!isNull _x && { alive _x } && { isPlayer _x } && { side group _x == _sideFriendly }) then {
                        private _uid = getPlayerUID _x;
                        if !(_uid in _selected) then {
                            private _idx = _lbA lbAdd (name _x);
                            _lbA lbSetData [_idx, _uid];
                        };
                    };
                } forEach allPlayers;
                {
                    private _uid = _x;
                    private _p = objNull;
                    { if (getPlayerUID _x == _uid) exitWith { _p = _x } } forEach allPlayers;
                    if (!isNull _p) then {
                        private _tag = if (_uid == _callerUid) then { " (you)" } else { "" };
                        private _idx = _lbS lbAdd ((name _p) + _tag);
                        _lbS lbSetData [_idx, _uid];
                    };
                } forEach _selected;
            };
            case "add": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbA = _display displayCtrl 60318;
                private _i = lbCurSel _lbA;
                if (_i < 0) exitWith { systemChat "TROOP TRANSPORT: select a player in Available first."; };
                private _uid = _lbA lbData _i;
                if (_uid == "") exitWith {};
                private _sel = +(uinamespace getVariable ["FAC_tiPick_selectedUids", []]);
                if !(_uid in _sel) then { _sel pushBack _uid };
                uinamespace setVariable ["FAC_tiPick_selectedUids", _sel];
                ["refreshLists", []] call FAC_troopInsertPickGui_fnc;
            };
            case "remove": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbS = _display displayCtrl 60319;
                private _i = lbCurSel _lbS;
                if (_i < 0) exitWith { systemChat "TROOP TRANSPORT: select a player in Participating first."; };
                private _uid = _lbS lbData _i;
                if (_uid == getPlayerUID player) exitWith {
                    private _mt = uinamespace getVariable ["FAC_tiPick_missionType", "TroopInsert"];
                    private _labels = [_mt] call FAC_troopInsertPickGui_fnc_missionLabels;
                    systemChat format ["%1: you must stay on the participating list.", _labels select 0];
                };
                private _sel = (uinamespace getVariable ["FAC_tiPick_selectedUids", []]) select { _x != _uid };
                uinamespace setVariable ["FAC_tiPick_selectedUids", _sel];
                ["refreshLists", []] call FAC_troopInsertPickGui_fnc;
            };
            case "confirm": {
                private _sel = +(uinamespace getVariable ["FAC_tiPick_selectedUids", []]);
                private _callerUid = getPlayerUID player;
                private _mt = uinamespace getVariable ["FAC_tiPick_missionType", "TroopInsert"];
                private _labels = [_mt] call FAC_troopInsertPickGui_fnc_missionLabels;
                if !(_callerUid in _sel) exitWith {
                    systemChat format ["%1: include yourself as a participating transport.", _labels select 0];
                };
                if (count _sel < 1) exitWith {};
                private _display = findDisplay 60002;
                private _waves = 1;
                if (!isNull _display) then {
                    private _sl = _display displayCtrl 60325;
                    if (!isNull _sl) then { _waves = round ((sliderPosition _sl) max 1 min 10) };
                };
                private _mapAnchor = uinamespace getVariable ["FAC_troopTransport_mapAnchor", []];
                if (!(_mapAnchor isEqualType []) || { count _mapAnchor < 2 }) then { _mapAnchor = [] };
                if (_mt == "TroopExtract") then {
                    [_sel, _waves, player, _mapAnchor] remoteExec ["FADE_startTroopExtract", 2];
                } else {
                    [_sel, _waves, player, _mapAnchor] remoteExec ["FADE_startTroopInsert", 2];
                };
                uinamespace setVariable ["FAC_troopTransport_mapAnchor", nil];
                uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
                systemChat format ["%1: requesting mission (%2 wave(s))...", _labels select 0, _waves];
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
            case "close": {
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_troopInsertPickGui_fnc", FAC_troopInsertPickGui_fnc];
    missionNamespace setVariable ["FAC_troopInsertPickGui_fnc_setWaveSlider", FAC_troopInsertPickGui_fnc_setWaveSlider];
};
