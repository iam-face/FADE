// =============================================================================
// EscapeEvasionPickGui.sqf  -  evadee selection overlay on Manage Missions (60002)
// =============================================================================
if (hasInterface) then {
    FAC_escapeEvasionPickGui_fnc_destroyOverlay = {
        ["FAC_eePick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };

    FAC_escapeEvasionPickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                if (isNull _display) exitWith {
                    systemChat "ESCAPE & EVASION: open Manage Missions first, then start this mission type.";
                };
                disableSerialization;
                [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay;
                [false] call FAC_missionPickOverlay_setBaseVisible;
                private _controls = [];
                private _bg = _display ctrlCreate ["RscText", 60280];
                _bg ctrlSetPosition [0.02, 0.09, 0.96, 0.72];
                _bg ctrlSetBackgroundColor FAC_theme_bgOverlay;
                _bg ctrlCommit 0;
                _controls pushBack _bg;
                private _title = _display ctrlCreate ["RscText", 60281];
                _title ctrlSetPosition [0.02, 0.09, 0.96, 0.048];
                _title ctrlSetText "ESCAPE & EVASION  -  SELECT EVADEES";
                _title ctrlSetBackgroundColor FAC_theme_bgOverlayTitle;
                _title ctrlCommit 0;
                _controls pushBack _title;
                private _help = _display ctrlCreate ["RscEdit", 60282];
                _help ctrlSetPosition [0.04, 0.148, 0.92, 0.10];
                _help ctrlSetText "You must stay in the right-hand list. Add players who will be teleported (dispersed in the AO). Others are the rescue party. No map markers. Success: all evadees within 1000 m of base.";
                _help ctrlEnable false;
                _help ctrlCommit 0;
                _controls pushBack _help;
                private _la = _display ctrlCreate ["RscText", 60289];
                _la ctrlSetPosition [0.04, 0.252, 0.42, 0.028];
                _la ctrlSetText "Available";
                _la ctrlCommit 0;
                _controls pushBack _la;
                private _ls = _display ctrlCreate ["RscText", 60290];
                _ls ctrlSetPosition [0.52, 0.252, 0.44, 0.028];
                _ls ctrlSetText "Evadees (teleported)";
                _ls ctrlCommit 0;
                _controls pushBack _ls;
                private _lbA = _display ctrlCreate ["RscListbox", 60283];
                _lbA ctrlSetPosition [0.04, 0.285, 0.42, 0.38];
                _lbA ctrlCommit 0;
                _controls pushBack _lbA;
                private _lbS = _display ctrlCreate ["RscListbox", 60284];
                _lbS ctrlSetPosition [0.52, 0.285, 0.44, 0.38];
                _lbS ctrlCommit 0;
                _controls pushBack _lbS;
                private _footer = [_display, 60285, 0.685, "FAC_escapeEvasionPickGui_fnc"] call FAC_missionPick_createParticipantFooter;
                _controls append _footer;
                uinamespace setVariable ["FAC_eePick_overlayCtrls", _controls];
                uinamespace setVariable ["FAC_eePick_selectedUids", [getPlayerUID player]];
                uinamespace setVariable ["FAC_escapeEvasionPickGui_fnc", FAC_escapeEvasionPickGui_fnc];
                ["refreshLists", []] call FAC_escapeEvasionPickGui_fnc;
            };
            case "refreshLists": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbA = _display displayCtrl 60283;
                private _lbS = _display displayCtrl 60284;
                if (isNull _lbA || { isNull _lbS }) exitWith {};
                private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
                private _selected = +(uinamespace getVariable ["FAC_eePick_selectedUids", []]);
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
                private _lbA = _display displayCtrl 60283;
                private _i = lbCurSel _lbA;
                if (_i < 0) exitWith {};
                private _uid = _lbA lbData _i;
                if (_uid == "") exitWith {};
                private _sel = +(uinamespace getVariable ["FAC_eePick_selectedUids", []]);
                if !(_uid in _sel) then { _sel pushBack _uid };
                uinamespace setVariable ["FAC_eePick_selectedUids", _sel];
                ["refreshLists", []] call FAC_escapeEvasionPickGui_fnc;
            };
            case "remove": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _lbS = _display displayCtrl 60284;
                private _i = lbCurSel _lbS;
                if (_i < 0) exitWith {};
                private _uid = _lbS lbData _i;
                if (_uid == getPlayerUID player) exitWith { systemChat "ESCAPE & EVASION: you must stay on the evadee list."; };
                private _sel = (uinamespace getVariable ["FAC_eePick_selectedUids", []]) select { _x != _uid };
                uinamespace setVariable ["FAC_eePick_selectedUids", _sel];
                ["refreshLists", []] call FAC_escapeEvasionPickGui_fnc;
            };
            case "confirm": {
                private _sel = +(uinamespace getVariable ["FAC_eePick_selectedUids", []]);
                private _callerUid = getPlayerUID player;
                if !(_callerUid in _sel) exitWith {
                    systemChat "ESCAPE & EVASION: include yourself as an evadee.";
                };
                if (count _sel < 1) exitWith {};
                [_sel, player] remoteExec ["FADE_startEscapeEvasion", 2];
                [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay;
                hint parseText "<t size='1.1' color='#A0D0A0'>Requesting Escape &amp; Evasion...</t>";
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
            case "close": {
                [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_escapeEvasionPickGui_fnc", FAC_escapeEvasionPickGui_fnc];
};
