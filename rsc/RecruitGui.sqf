// =============================================================================
// RecruitGui.sqf — HQ recruit board (client), idd 60940
// =============================================================================

FAC_recruitGui_IDD = 60940;

FAC_recruitGui_recruitIdcs = [60943, 60944, 60951, 60958, 60952, 60949, 60959, 60950, 60947, 60948, 60953];
FAC_recruitGui_rosterIdcs = [60954, 60955, 60956];

FAC_recruitGui_setCtrlShow = {
    params ["_display", "_idcs", "_show"];
    { (_display displayCtrl _x) ctrlShow _show } forEach _idcs;
};

FAC_recruitGui_updateTabButtons = {
    params ["_display"];
    private _tab = missionNamespace getVariable ["FAC_recruitGui_tab", "recruit"];
    private _active = FAC_theme_tabActive;
    private _idle = FAC_theme_tabIdle;
    private _bRec = _display displayCtrl 60941;
    private _bRos = _display displayCtrl 60942;
    if (_tab == "recruit") then {
        _bRec ctrlSetBackgroundColor _active;
        _bRos ctrlSetBackgroundColor _idle;
    } else {
        _bRec ctrlSetBackgroundColor _idle;
        _bRos ctrlSetBackgroundColor _active;
    };
};

FAC_recruitGui_updateSourceButtons = {
    params ["_display"];
    private _mode = missionNamespace getVariable ["FAC_recruitGui_listMode", "preset"];
    private _active = FAC_theme_tabActive;
    private _idle = FAC_theme_tabIdle;
    private _bPreset = _display displayCtrl 60943;
    private _bStd = _display displayCtrl 60944;
    if (_mode == "preset") then {
        _bPreset ctrlSetBackgroundColor _active;
        _bStd ctrlSetBackgroundColor _idle;
    } else {
        _bPreset ctrlSetBackgroundColor _idle;
        _bStd ctrlSetBackgroundColor _active;
    };
};

FAC_recruitGui_fillAssignList = {
    params ["_display"];
    private _lb = _display displayCtrl 60952;
    lbClear _lb;
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", side player];
    private _idx = _lb lbAdd format ["Me (%1)", name player];
    _lb lbSetData [_idx, netId player];
    {
        if (isPlayer _x && { alive _x } && { _x != player } && { side _x == _sideF }) then {
            private _i = _lb lbAdd format ["%1 (group leader: %2)", name _x, name (leader group _x)];
            _lb lbSetData [_i, netId _x];
        };
    } forEach allPlayers;
    if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
};

FAC_recruitGui_populatePresetList = {
    params ["_display"];
    if (!([] call FAC_loadoutGui_ensurePresetData)) exitWith {
        systemChat "[Recruit] Presets failed to load - check RPT and PresetLoadouts.sqf.";
        missionNamespace setVariable ["FAC_recruitGui_allUnits", []];
    };
    missionNamespace setVariable ["FAC_recruitGui_allUnits", [] call FAC_loadoutGui_buildPresetEntries];
    private _factionList = _display displayCtrl 60949;
    lbClear _factionList;
    (_display displayCtrl 60958) ctrlSetText "Era";
    private _idx = _factionList lbAdd "All eras";
    _factionList lbSetData [_idx, ""];
    _factionList lbSetCurSel 0;
    private _preset = missionNamespace getVariable ["FAC_presetLoadouts", []];
    {
        _x params ["_eraKey", "_eraDn", "_roles"];
        if (_eraKey != "" && { count _roles > 0 }) then {
            _idx = _factionList lbAdd _eraDn;
            _factionList lbSetData [_idx, _eraKey];
        };
    } forEach _preset;
    ["filterChanged", []] call FAC_recruitGui_fnc;
};

FAC_recruitGui_populateFactionList = {
    params ["_display", "_rows", "_defaultFac"];
    private _factionList = _display displayCtrl 60949;
    lbClear _factionList;
    (_display displayCtrl 60958) ctrlSetText "Faction";
    private _selIdx = 0;
    private _idx = _factionList lbAdd "All factions";
    _factionList lbSetData [_idx, ""];
    {
        _x params ["_dn", "_key"];
        _idx = _factionList lbAdd _dn;
        _factionList lbSetData [_idx, _key];
        if (_key == _defaultFac) then { _selIdx = _idx };
    } forEach _rows;
    _factionList lbSetCurSel _selIdx;
    private _fac = _factionList lbData _selIdx;
    if (_fac == "") then { _fac = _defaultFac };
    missionNamespace setVariable ["FAC_recruitGui_pendingFaction", _fac];
    [player, _fac] remoteExec ["FADE_recruit_requestFactionUnits", 2];
};

FAC_recruitGui_applyUnitRows = {
    params ["_display", "_rows"];
    private _listMode = missionNamespace getVariable ["FAC_recruitGui_listMode", "preset"];
    private _filterFaction = "";
    private _factionList = _display displayCtrl 60949;
    private _fSel = lbCurSel _factionList;
    if (_fSel >= 0) then { _filterFaction = _factionList lbData _fSel };

    private _searchText = toLower (ctrlText (_display displayCtrl 60950));
    private _filtered = [];
    {
        if (_listMode == "preset") then {
            _x params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
            if (_filterFaction == "" || { _faction == _filterFaction }) then {
                private _label = _factionDn + " > " + _displayName;
                if (_searchText == "" || { (toLower _label) find _searchText >= 0 }) then {
                    _filtered pushBack _x;
                };
            };
        } else {
            _x params ["_class", "_displayName", "_typeDn"];
            private _facDn = if (_filterFaction != "") then {
                [_filterFaction] call FAC_loadoutGui_getFactionDisplayName
            } else {
                "Unit"
            };
            private _label = _facDn + " > " + _typeDn + " > " + _displayName;
            if (_searchText == "" || { (toLower _label) find _searchText >= 0 }) then {
                _filtered pushBack [_class, _displayName, _filterFaction, _facDn, _typeDn];
            };
        };
    } forEach _rows;

    if (_listMode == "preset") then {
        _filtered = _filtered apply { [_x select 3, _x select 1, _x] };
    } else {
        _filtered = _filtered apply { [_x select 3, _x select 4, _x select 1, _x] };
    };
    _filtered sort true;

    private _unitLb = _display displayCtrl 60948;
    lbClear _unitLb;
    {
        private _entry = _x select ((count _x) - 1);
        _entry params ["_class", "_displayName", "_faction", "_factionDn", "_typeDn"];
        private _label = if (_listMode == "preset") then {
            _factionDn + " > " + _displayName
        } else {
            _factionDn + " > " + _typeDn + " > " + _displayName
        };
        private _idx = _unitLb lbAdd _label;
        _unitLb lbSetData [_idx, _class];
        private _pic = "\a3\ui_f\data\map\markers\nato\b_inf.paa";
        if ((_class find "FAC:") != 0) then {
            _pic = [_class] call FAC_loadoutGui_getUnitPicture;
        };
        _unitLb lbSetPicture [_idx, _pic];
        private _tip = if ((_class find "FAC:") == 0) then {
            private _arr = [_class] call FAC_loadoutGui_getPresetLoadoutByKey;
            [_arr] call FAC_loadoutGui_buildLoadoutTextFromArray
        } else {
            [_class] call FAC_loadoutGui_buildLoadoutText
        };
        _unitLb lbSetTooltip [_idx, _tip];
    } forEach _filtered;
    if (lbSize _unitLb > 0) then { _unitLb lbSetCurSel 0 };
};

FAC_recruitGui_onFactionList = {
    params ["_rows", "_defaultFac"];
    private _display = findDisplay FAC_recruitGui_IDD;
    if (isNull _display) exitWith {};
    missionNamespace setVariable ["FAC_recruitGui_factionRows", _rows];
    [_display, _rows, _defaultFac] call FAC_recruitGui_populateFactionList;
};

FAC_recruitGui_onFactionUnits = {
    params ["_faction", "_rows"];
    private _pending = missionNamespace getVariable ["FAC_recruitGui_pendingFaction", ""];
    if (_faction != _pending) exitWith {};
    missionNamespace setVariable ["FAC_recruitGui_allUnits", _rows];
    private _display = findDisplay FAC_recruitGui_IDD;
    if (isNull _display) exitWith {};
    if ((missionNamespace getVariable ["FAC_recruitGui_listMode", "preset"]) != "std") exitWith {};
    ["filterChanged", []] call FAC_recruitGui_fnc;
};

FAC_recruitGui_onRoster = {
    params ["_rows"];
    private _display = findDisplay FAC_recruitGui_IDD;
    if (isNull _display) exitWith {};
    private _lb = _display displayCtrl 60955;
    lbClear _lb;
    {
        _x params ["_netId", "_label"];
        private _idx = _lb lbAdd _label;
        _lb lbSetData [_idx, _netId];
    } forEach _rows;
    if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
};

FAC_recruitGui_layoutSourceButtons = {
    params ["_display", ["_bothVisible", true]];
    private _btnPreset = _display displayCtrl 60943;
    private _btnStd = _display displayCtrl 60944;
    if (_bothVisible) then {
        _btnPreset ctrlSetPosition [0.04, 0.102, 0.45, 0.042];
        _btnStd ctrlSetPosition [0.51, 0.102, 0.45, 0.042];
    } else {
        _btnPreset ctrlSetPosition [0.04, 0.102, 0.92, 0.042];
        _btnStd ctrlSetPosition [0.04, 0.102, 0.92, 0.042];
    };
    _btnPreset ctrlCommit 0;
    _btnStd ctrlCommit 0;
};

FAC_recruitGui_populateWorker = {
    params ["_display"];
    if (isNull _display) exitWith {};

    private _limitToBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
    private _limitToPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
    private _forceStd = _limitToBlu;
    private _forcePreset = (!_forceStd) && { _limitToPreset };

    private _btnPreset = _display displayCtrl 60943;
    private _btnStd = _display displayCtrl 60944;
    _btnPreset ctrlShow true;
    _btnStd ctrlShow true;

    if (_forceStd) then {
        _btnPreset ctrlShow false;
        _btnStd ctrlShow true;
        [_display, false] call FAC_recruitGui_layoutSourceButtons;
        missionNamespace setVariable ["FAC_recruitGui_listMode", "std"];
        [player] remoteExec ["FADE_recruit_requestFactionList", 2];
    } else {
        if (_forcePreset) then {
            _btnStd ctrlShow false;
            _btnPreset ctrlShow true;
            [_display, false] call FAC_recruitGui_layoutSourceButtons;
        } else {
            _btnPreset ctrlShow true;
            _btnStd ctrlShow true;
            [_display, true] call FAC_recruitGui_layoutSourceButtons;
        };
        missionNamespace setVariable ["FAC_recruitGui_listMode", "preset"];
        [_display] call FAC_recruitGui_populatePresetList;
    };
    [_display] call FAC_recruitGui_updateSourceButtons;
    [_display] call FAC_recruitGui_fillAssignList;
};

FAC_recruitGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay FAC_recruitGui_IDD;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if !(["FAC_playerCanUseRecruitGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Recruit GUI access denied by lobby settings.";
            };
            if (!createDialog "RscDisplayRecruit") then {
                systemChat "RECRUIT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            _display = findDisplay FAC_recruitGui_IDD;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_recruitGui_fnc", FAC_recruitGui_fnc];
            uinamespace setVariable ["FAC_recruitGui_fnc", FAC_recruitGui_fnc];
            missionNamespace setVariable ["FAC_recruitGui_tab", "recruit"];

            [_display, FAC_recruitGui_recruitIdcs, true] call FAC_recruitGui_setCtrlShow;
            [_display, FAC_recruitGui_rosterIdcs, false] call FAC_recruitGui_setCtrlShow;
            [_display] call FAC_recruitGui_updateTabButtons;

            private _unitLb = _display displayCtrl 60948;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;

            [] spawn {
                private _display = findDisplay FAC_recruitGui_IDD;
                if (isNull _display) exitWith {};
                [_display] call FAC_recruitGui_populateWorker;
            };
        };
        case "setTab": {
            _params params [["_tab", "recruit"]];
            missionNamespace setVariable ["FAC_recruitGui_tab", _tab];
            [_display] call FAC_recruitGui_updateTabButtons;
            private _isRecruit = _tab == "recruit";
            [_display, FAC_recruitGui_recruitIdcs, _isRecruit] call FAC_recruitGui_setCtrlShow;
            [_display, FAC_recruitGui_rosterIdcs, !_isRecruit] call FAC_recruitGui_setCtrlShow;
            if (!_isRecruit) then {
                [player] remoteExec ["FADE_recruit_requestRoster", 2];
            };
        };
        case "sourcePick": {
            _params params [["_mode", "preset"]];
            private _limitToBlu = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
            private _limitToPreset = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
            if (_limitToBlu && { _mode != "std" }) exitWith { systemChat "Recruit: scenario limits to friendly faction units."; };
            if (_limitToPreset && { _mode != "preset" }) exitWith { systemChat "Recruit: scenario allows preset loadouts only."; };
            missionNamespace setVariable ["FAC_recruitGui_listMode", _mode];
            [_display] call FAC_recruitGui_updateSourceButtons;
            private _limitPresetOnly = missionNamespace getVariable ["FADE_limitToPresetLoadouts", false];
            private _limitBluOnly = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
            [_display, !(_limitBluOnly || _limitPresetOnly)] call FAC_recruitGui_layoutSourceButtons;
            private _unitLb = _display displayCtrl 60948;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;
            if (_mode == "preset") then {
                [_display] call FAC_recruitGui_populatePresetList;
            } else {
                [player] remoteExec ["FADE_recruit_requestFactionList", 2];
            };
        };
        case "factionChanged": {
            if ((missionNamespace getVariable ["FAC_recruitGui_listMode", "preset"]) == "preset") exitWith {
                ["filterChanged", []] call FAC_recruitGui_fnc;
            };
            private _fSel = lbCurSel (_display displayCtrl 60949);
            if (_fSel < 0) exitWith {};
            private _fac = (_display displayCtrl 60949) lbData _fSel;
            if (_fac == "") then {
                _fac = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
            };
            missionNamespace setVariable ["FAC_recruitGui_pendingFaction", _fac];
            private _unitLb = _display displayCtrl 60948;
            lbClear _unitLb;
            _unitLb lbAdd "Loading...";
            _unitLb lbSetCurSel 0;
            [player, _fac] remoteExec ["FADE_recruit_requestFactionUnits", 2];
        };
        case "filterChanged": {
            private _rows = missionNamespace getVariable ["FAC_recruitGui_allUnits", []];
            [_display, _rows] call FAC_recruitGui_applyUnitRows;
        };
        case "unitSelChanged": {};
        case "headerRefresh": {
            private _tab = missionNamespace getVariable ["FAC_recruitGui_tab", "recruit"];
            if (_tab == "roster") then {
                [player] remoteExec ["FADE_recruit_requestRoster", 2];
            } else {
                [_display] call FAC_recruitGui_populateWorker;
            };
        };
        case "recruit": {
            private _unitLb = _display displayCtrl 60948;
            private _idx = lbCurSel _unitLb;
            if (_idx < 0) exitWith { systemChat "Select a unit to recruit."; };
            private _rowKey = _unitLb lbData _idx;
            if (_rowKey == "") exitWith { systemChat "Recruit: no row data - re-open the dialog."; };
            private _assignLb = _display displayCtrl 60952;
            private _aIdx = lbCurSel _assignLb;
            if (_aIdx < 0) exitWith { systemChat "Select a player to assign the recruit to."; };
            private _targetNetId = _assignLb lbData _aIdx;
            [player, _targetNetId, _rowKey] remoteExec ["FADE_recruit_spawnUnit", 2];
        };
        case "dismiss": {
            private _lb = _display displayCtrl 60955;
            private _sel = lbCurSel _lb;
            if (_sel < 0) exitWith { systemChat "Select recruited unit(s) to dismiss."; };
            private _netIds = [];
            for "_i" from 0 to ((lbSize _lb) - 1) do {
                if (_lb lbIsSelected _i) then {
                    private _nid = _lb lbData _i;
                    if (_nid != "") then { _netIds pushBack _nid };
                };
            };
            if (_netIds isEqualTo []) then {
                private _one = _lb lbData _sel;
                if (_one != "") then { _netIds = [_one] };
            };
            if (_netIds isEqualTo []) exitWith { systemChat "Select recruited unit(s) to dismiss."; };
            [player, _netIds] remoteExec ["FADE_recruit_dismissUnits", 2];
        };
    };
};

missionNamespace setVariable ["FAC_recruitGui_onFactionList", FAC_recruitGui_onFactionList];
missionNamespace setVariable ["FAC_recruitGui_onFactionUnits", FAC_recruitGui_onFactionUnits];
missionNamespace setVariable ["FAC_recruitGui_onRoster", FAC_recruitGui_onRoster];
missionNamespace setVariable ["FAC_recruitGui_fnc", FAC_recruitGui_fnc];
