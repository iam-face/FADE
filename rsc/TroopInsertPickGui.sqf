// =============================================================================
// TroopInsertPickGui.sqf — participating pilots/drivers + One-Off / Recurring (60002 overlay)
// =============================================================================
if (hasInterface) then {
    FAC_troopInsertPickGui_fnc_baseMissionsIdcs = [60133, 60110, 60111, 60112, 60113, 60114, 60115, 60120, 60131, 60121, 60130, 60134, 60135, 60136, 60150, 60151, 60152, 60153];

    FAC_troopInsertPickGui_fnc_setBaseMissionsLayerVisible = {
        params [["_show", true]];
        private _d = findDisplay 60002;
        if (isNull _d) exitWith {};
        {
            private _c = _d displayCtrl _x;
            if (!isNull _c) then { _c ctrlShow _show };
        } forEach FAC_troopInsertPickGui_fnc_baseMissionsIdcs;
    };

    FAC_troopInsertPickGui_fnc_destroyOverlay = {
        private _lst = uinamespace getVariable ["FAC_tiPick_overlayCtrls", []];
        { if (!isNull _x) then { ctrlDelete _x } } forEach _lst;
        uinamespace setVariable ["FAC_tiPick_overlayCtrls", nil];
        [true] call FAC_troopInsertPickGui_fnc_setBaseMissionsLayerVisible;
    };

    FAC_troopInsertPickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                if (isNull _display) exitWith {
                    systemChat "TROOP INSERT: open Manage Missions first, then start this mission type.";
                };
                disableSerialization;
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
                [false] call FAC_troopInsertPickGui_fnc_setBaseMissionsLayerVisible;
                private _controls = [];
                private _bg = _display ctrlCreate ["RscText", 60310];
                _bg ctrlSetPosition [0.02, 0.09, 0.96, 0.76];
                _bg ctrlSetBackgroundColor [0.06, 0.07, 0.1, 0.96];
                _bg ctrlCommit 0;
                _controls pushBack _bg;
                private _title = _display ctrlCreate ["RscText", 60311];
                _title ctrlSetPosition [0.02, 0.09, 0.96, 0.048];
                _title ctrlSetText "TROOP INSERT — PARTICIPATING TRANSPORTS";
                _title ctrlSetBackgroundColor [0.15, 0.28, 0.42, 1];
                _title ctrlCommit 0;
                _controls pushBack _title;
                private _help = _display ctrlCreate ["RscStructuredText", 60312];
                _help ctrlSetPosition [0.04, 0.148, 0.92, 0.12];
                _help ctrlSetBackgroundColor [0, 0, 0, 0.55];
                _help ctrlSetStructuredText parseText (
                    "<t size='0.78' color='#B8B8B8'>Select pilots/drivers only - one distinct vehicle per participant. Vehicle checks apply at pickup.</t><br/>" +
                    "<t size='0.78' color='#B8B8B8'>One-Off: single drop, then the mission ends.</t><br/>" +
                    "<t size='0.78' color='#B8B8B8'>Recurring: after each drop, new squads spawn near you for another pickup and a random shared LZ.</t>"
                );
                _help ctrlCommit 0;
                _controls pushBack _help;
                private _modeLbl = _display ctrlCreate ["RscText", 60313];
                _modeLbl ctrlSetPosition [0.04, 0.278, 0.92, 0.028];
                _modeLbl ctrlSetText "Mission mode (choose one)";
                _modeLbl ctrlCommit 0;
                _controls pushBack _modeLbl;
                private _bOne = _display ctrlCreate ["RscButton", 60314];
                _bOne ctrlSetPosition [0.04, 0.308, 0.44, 0.04];
                _bOne ctrlSetText "One-Off";
                _bOne ctrlSetBackgroundColor [0.2, 0.45, 0.5, 1];
                _bOne ctrlCommit 0;
                _bOne ctrlAddEventHandler ["ButtonClick", { uinamespace setVariable ["FAC_tiPick_mode", "oneOff"]; ["refreshMode", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bOne;
                private _bRec = _display ctrlCreate ["RscButton", 60315];
                _bRec ctrlSetPosition [0.52, 0.308, 0.44, 0.04];
                _bRec ctrlSetText "Recurring";
                _bRec ctrlSetBackgroundColor [0.1, 0.12, 0.16, 1];
                _bRec ctrlCommit 0;
                _bRec ctrlAddEventHandler ["ButtonClick", { uinamespace setVariable ["FAC_tiPick_mode", "recurring"]; ["refreshMode", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bRec;
                private _la = _display ctrlCreate ["RscText", 60316];
                _la ctrlSetPosition [0.04, 0.358, 0.42, 0.028];
                _la ctrlSetText "Available";
                _la ctrlCommit 0;
                _controls pushBack _la;
                private _ls = _display ctrlCreate ["RscText", 60317];
                _ls ctrlSetPosition [0.52, 0.358, 0.44, 0.028];
                _ls ctrlSetText "Participating (transport)";
                _ls ctrlCommit 0;
                _controls pushBack _ls;
                private _lbA = _display ctrlCreate ["RscListbox", 60318];
                _lbA ctrlSetPosition [0.04, 0.39, 0.42, 0.34];
                _lbA ctrlCommit 0;
                _controls pushBack _lbA;
                private _lbS = _display ctrlCreate ["RscListbox", 60319];
                _lbS ctrlSetPosition [0.52, 0.39, 0.44, 0.34];
                _lbS ctrlCommit 0;
                _controls pushBack _lbS;
                private _ba = _display ctrlCreate ["RscButton", 60320];
                _ba ctrlSetPosition [0.04, 0.745, 0.20, 0.045];
                _ba ctrlSetText "Add ->";
                _ba ctrlSetBackgroundColor [0.18, 0.32, 0.48, 1];
                _ba ctrlCommit 0;
                _ba ctrlAddEventHandler ["ButtonClick", { ["add", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _ba;
                private _br = _display ctrlCreate ["RscButton", 60321];
                _br ctrlSetPosition [0.26, 0.745, 0.20, 0.045];
                _br ctrlSetText "<- Remove";
                _br ctrlSetBackgroundColor [0.18, 0.32, 0.48, 1];
                _br ctrlCommit 0;
                _br ctrlAddEventHandler ["ButtonClick", { ["remove", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _br;
                private _bs = _display ctrlCreate ["RscButton", 60322];
                _bs ctrlSetPosition [0.52, 0.745, 0.22, 0.045];
                _bs ctrlSetText "START";
                _bs ctrlSetBackgroundColor [0.2, 0.45, 0.5, 1];
                _bs ctrlCommit 0;
                _bs ctrlAddEventHandler ["ButtonClick", { ["confirm", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bs;
                private _bc = _display ctrlCreate ["RscButton", 60323];
                _bc ctrlSetPosition [0.76, 0.745, 0.20, 0.045];
                _bc ctrlSetText "Cancel";
                _bc ctrlSetBackgroundColor [0.4, 0.2, 0.2, 1];
                _bc ctrlCommit 0;
                _bc ctrlAddEventHandler ["ButtonClick", { ["close", []] call (missionNamespace getVariable ["FAC_troopInsertPickGui_fnc", {}]) }];
                _controls pushBack _bc;
                uinamespace setVariable ["FAC_tiPick_overlayCtrls", _controls];
                uinamespace setVariable ["FAC_tiPick_selectedUids", [getPlayerUID player]];
                uinamespace setVariable ["FAC_tiPick_mode", "oneOff"];
                uinamespace setVariable ["FAC_troopInsertPickGui_fnc", FAC_troopInsertPickGui_fnc];
                ["refreshLists", []] call FAC_troopInsertPickGui_fnc;
                ["refreshMode", []] call FAC_troopInsertPickGui_fnc;
            };
            case "refreshMode": {
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _m = uinamespace getVariable ["FAC_tiPick_mode", "oneOff"];
                private _sel = [0.2, 0.45, 0.5, 1];
                private _idle = [0.1, 0.12, 0.16, 1];
                (_display displayCtrl 60314) ctrlSetBackgroundColor (if (_m == "oneOff") then { _sel } else { _idle });
                (_display displayCtrl 60315) ctrlSetBackgroundColor (if (_m == "recurring") then { _sel } else { _idle });
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
                if (_i < 0) exitWith {};
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
                if (_i < 0) exitWith {};
                private _uid = _lbS lbData _i;
                if (_uid == getPlayerUID player) exitWith { systemChat "TROOP INSERT: you must stay on the participating list."; };
                private _sel = (uinamespace getVariable ["FAC_tiPick_selectedUids", []]) select { _x != _uid };
                uinamespace setVariable ["FAC_tiPick_selectedUids", _sel];
                ["refreshLists", []] call FAC_troopInsertPickGui_fnc;
            };
            case "confirm": {
                private _sel = +(uinamespace getVariable ["FAC_tiPick_selectedUids", []]);
                private _callerUid = getPlayerUID player;
                if !(_callerUid in _sel) exitWith {
                    systemChat "TROOP INSERT: include yourself as a participating transport.";
                };
                if (count _sel < 1) exitWith {};
                private _mode = uinamespace getVariable ["FAC_tiPick_mode", "oneOff"];
                if !(_mode in ["oneOff", "recurring"]) then { _mode = "oneOff" };
                private _lzAnchor = uinamespace getVariable ["FAC_troopInsert_lzAnchor", []];
                if (!(_lzAnchor isEqualType []) || { count _lzAnchor < 2 }) then { _lzAnchor = [] };
                [_sel, _mode, player, _lzAnchor] remoteExec ["FADE_startTroopInsert", 2];
                uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
                hint parseText "<t size='1.1' color='#A0D0A0'>Requesting Troop Insert...</t>";
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
            case "close": {
                [] call FAC_troopInsertPickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_troopInsertPickGui_fnc", FAC_troopInsertPickGui_fnc];
};
