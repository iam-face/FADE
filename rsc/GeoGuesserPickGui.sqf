// =============================================================================
// GeoGuesserPickGui.sqf  -  participant / time / difficulty overlay (60002)
// =============================================================================
if (hasInterface) then {
    FAC_geoGuesserPickGui_fnc_destroyOverlay = {
        ["FAC_ggPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };

    FAC_geoGuesserPickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                if (isNull _display) exitWith {
                    systemChat "GEO-GUESSER: open Manage Missions first, then start this mission type.";
                };
                disableSerialization;
                [] call FAC_geoGuesserPickGui_fnc_destroyOverlay;
                [false] call FAC_missionPickOverlay_setBaseVisible;
                private _controls = [];
                private _bg = _display ctrlCreate ["RscText", 60300];
                _bg ctrlSetPosition [0.02, 0.08, 0.96, 0.74];
                _bg ctrlSetBackgroundColor [0.06, 0.07, 0.1, 0.96];
                _bg ctrlCommit 0;
                _controls pushBack _bg;
                private _title = _display ctrlCreate ["RscText", 60301];
                _title ctrlSetPosition [0.02, 0.08, 0.96, 0.048];
                _title ctrlSetText "GEO-GUESSER  -  SETUP";
                _title ctrlSetBackgroundColor [0.15, 0.28, 0.42, 1];
                _title ctrlCommit 0;
                _controls pushBack _title;
                private _help = _display ctrlCreate ["RscEdit", 60302];
                _help ctrlSetPosition [0.04, 0.136, 0.92, 0.09];
                _help ctrlSetText "Navigation drill: participants are teleported to a random map location and must click the map where they think they are. Faster guesses score higher. You must include yourself.";
                _help ctrlEnable false;
                _help ctrlCommit 0;
                _controls pushBack _help;
                private _la = _display ctrlCreate ["RscText", 60303];
                _la ctrlSetPosition [0.04, 0.232, 0.42, 0.028];
                _la ctrlSetText "Available";
                _la ctrlCommit 0;
                _controls pushBack _la;
                private _ls = _display ctrlCreate ["RscText", 60304];
                _ls ctrlSetPosition [0.52, 0.232, 0.44, 0.028];
                _ls ctrlSetText "Participants";
                _ls ctrlCommit 0;
                _controls pushBack _ls;
                private _lbA = _display ctrlCreate ["RscListbox", 60305];
                _lbA ctrlSetPosition [0.04, 0.265, 0.42, 0.34];
                _lbA ctrlCommit 0;
                _controls pushBack _lbA;
                private _lbS = _display ctrlCreate ["RscListbox", 60306];
                _lbS ctrlSetPosition [0.52, 0.265, 0.44, 0.34];
                _lbS ctrlCommit 0;
                _controls pushBack _lbS;
                private _timeLbl = _display ctrlCreate ["RscText", 60307];
                _timeLbl ctrlSetPosition [0.04, 0.618, 0.42, 0.028];
                _timeLbl ctrlSetText "Round time (seconds)";
                _timeLbl ctrlCommit 0;
                _controls pushBack _timeLbl;
                private _timeVal = _display ctrlCreate ["RscText", 60308];
                _timeVal ctrlSetPosition [0.52, 0.618, 0.44, 0.028];
                _timeVal ctrlSetText "60 s";
                _timeVal ctrlCommit 0;
                _controls pushBack _timeVal;
                private _timeSl = _display ctrlCreate ["RscXSliderH", 60309];
                _timeSl ctrlSetPosition [0.04, 0.650, 0.92, 0.032];
                _timeSl sliderSetRange [30, 600];
                _timeSl sliderSetPosition 60;
                _timeSl ctrlAddEventHandler ["SliderPosChanged", {
                    ["timeSlider", []] call (missionNamespace getVariable ["FAC_geoGuesserPickGui_fnc", {}]);
                }];
                _timeSl ctrlCommit 0;
                _controls pushBack _timeSl;
                _controls pushBack _timeVal;
                private _diffLbl = _display ctrlCreate ["RscText", 60310];
                _diffLbl ctrlSetPosition [0.04, 0.692, 0.42, 0.028];
                _diffLbl ctrlSetText "Difficulty";
                _diffLbl ctrlCommit 0;
                _controls pushBack _diffLbl;
                private _diffCb = _display ctrlCreate ["RscCombo", 60311];
                _diffCb ctrlSetPosition [0.52, 0.688, 0.44, 0.034];
                private _d0 = _diffCb lbAdd "Normal  -  map + GPS; nearer settlements";
                _diffCb lbSetData [_d0, "Normal"];
                private _d1 = _diffCb lbAdd "Hard  -  no GPS; rural drops";
                _diffCb lbSetData [_d1, "Hard"];
                private _d2 = _diffCb lbAdd "Impossible  -  no GPS; remote terrain";
                _diffCb lbSetData [_d2, "Impossible"];
                _diffCb lbSetCurSel 0;
                _diffCb ctrlCommit 0;
                _controls pushBack _diffCb;
                private _ba = _display ctrlCreate ["RscButton", 60312];
                _ba ctrlSetPosition [0.04, 0.735, 0.20, 0.045];
                _ba ctrlSetText "Add ->";
                _ba ctrlSetBackgroundColor [0.18, 0.32, 0.48, 1];
                _ba ctrlCommit 0;
                _ba ctrlAddEventHandler ["ButtonClick", { ["add", []] call (missionNamespace getVariable ["FAC_geoGuesserPickGui_fnc", {}]) }];
                _controls pushBack _ba;
                private _br = _display ctrlCreate ["RscButton", 60313];
                _br ctrlSetPosition [0.26, 0.735, 0.20, 0.045];
                _br ctrlSetText "<- Remove";
                _br ctrlSetBackgroundColor [0.18, 0.32, 0.48, 1];
                _br ctrlCommit 0;
                _br ctrlAddEventHandler ["ButtonClick", { ["remove", []] call (missionNamespace getVariable ["FAC_geoGuesserPickGui_fnc", {}]) }];
                _controls pushBack _br;
                private _bs = _display ctrlCreate ["RscButton", 60314];
                _bs ctrlSetPosition [0.52, 0.735, 0.22, 0.045];
                _bs ctrlSetText "START";
                _bs ctrlSetBackgroundColor [0.2, 0.45, 0.5, 1];
                _bs ctrlCommit 0;
                _bs ctrlAddEventHandler ["ButtonClick", { ["confirm", []] call (missionNamespace getVariable ["FAC_geoGuesserPickGui_fnc", {}]) }];
                _controls pushBack _bs;
                private _bc = _display ctrlCreate ["RscButton", 60315];
                _bc ctrlSetPosition [0.76, 0.735, 0.20, 0.045];
                _bc ctrlSetText "Cancel";
                _bc ctrlSetBackgroundColor [0.4, 0.2, 0.2, 1];
                _bc ctrlCommit 0;
                _bc ctrlAddEventHandler ["ButtonClick", { ["close", []] call (missionNamespace getVariable ["FAC_geoGuesserPickGui_fnc", {}]) }];
                _controls pushBack _bc;
                uinamespace setVariable ["FAC_ggPick_overlayCtrls", _controls];
                uinamespace setVariable ["FAC_ggPick_selectedUids", [getPlayerUID player]];
                uinamespace setVariable ["FAC_geoGuesserPickGui_fnc", FAC_geoGuesserPickGui_fnc];
                ["refreshLists", []] call FAC_geoGuesserPickGui_fnc;
            };
            case "timeSlider": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _sl = _display displayCtrl 60309;
                private _tv = _display displayCtrl 60308;
                if (isNull _sl || { isNull _tv }) exitWith {};
                private _sec = round (sliderPosition _sl);
                _sec = _sec max 30 min 600;
                _tv ctrlSetText format ["%1 s", _sec];
            };
            case "refreshLists": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbA = _display displayCtrl 60305;
                private _lbS = _display displayCtrl 60306;
                if (isNull _lbA || { isNull _lbS }) exitWith {};
                private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
                private _selected = +(uinamespace getVariable ["FAC_ggPick_selectedUids", []]);
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
                private _lbA = _display displayCtrl 60305;
                private _i = lbCurSel _lbA;
                if (_i < 0) exitWith {};
                private _uid = _lbA lbData _i;
                if (_uid == "") exitWith {};
                private _sel = +(uinamespace getVariable ["FAC_ggPick_selectedUids", []]);
                if !(_uid in _sel) then { _sel pushBack _uid };
                uinamespace setVariable ["FAC_ggPick_selectedUids", _sel];
                ["refreshLists", []] call FAC_geoGuesserPickGui_fnc;
            };
            case "remove": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbS = _display displayCtrl 60306;
                private _i = lbCurSel _lbS;
                if (_i < 0) exitWith {};
                private _uid = _lbS lbData _i;
                if (_uid == getPlayerUID player) exitWith { systemChat "GEO-GUESSER: you must stay on the participant list."; };
                private _sel = (uinamespace getVariable ["FAC_ggPick_selectedUids", []]) select { _x != _uid };
                uinamespace setVariable ["FAC_ggPick_selectedUids", _sel];
                ["refreshLists", []] call FAC_geoGuesserPickGui_fnc;
            };
            case "confirm": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _sel = +(uinamespace getVariable ["FAC_ggPick_selectedUids", []]);
                private _callerUid = getPlayerUID player;
                if !(_callerUid in _sel) exitWith {
                    systemChat "GEO-GUESSER: include yourself as a participant.";
                };
                if (count _sel < 1) exitWith {};
                private _sl = _display displayCtrl 60309;
                private _cb = _display displayCtrl 60311;
                private _timeSec = 60;
                if (!isNull _sl) then { _timeSec = round (sliderPosition _sl) max 30 min 600 };
                private _diff = "Normal";
                if (!isNull _cb) then {
                    private _di = lbCurSel _cb;
                    if (_di >= 0) then { _diff = _cb lbData _di };
                };
                [_sel, _timeSec, _diff, player] remoteExec ["FADE_startGeoGuesser", 2];
                if (!isNil "FADE_ggClient_closeMissionGui") then { [] call FADE_ggClient_closeMissionGui } else { [] call FAC_geoGuesserPickGui_fnc_destroyOverlay };
                if (!isNull (findDisplay 60002)) then { closeDialog 0 };
                hint parseText "<t size='1.1' color='#A0D0A0'>Requesting Geo-Guesser...</t>";
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
            case "close": {
                [] call FAC_geoGuesserPickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_geoGuesserPickGui_fnc", FAC_geoGuesserPickGui_fnc];
};
