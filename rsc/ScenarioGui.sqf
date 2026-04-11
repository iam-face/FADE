// =============================================================================
// ScenarioGui.sqf - Scenario settings: tabs (Scenario / Factions / Admin), toggles, weather sliders
// =============================================================================

FAC_scenarioGui_IDD = 60003;
FAC_scenarioGui_act = [0.22, 0.48, 0.78, 1];
FAC_scenarioGui_inact = [0.07, 0.11, 0.20, 1];

// Preset id -> [overcast, rain, fogD, fogDecay, fogBase, windStr, windDir, gusts, waves] (matches server FADE_getWeatherParamsForPresetName)
FAC_scenarioGui_getWeatherParamsForPresetId = {
    params ["_id"];
    switch _id do {
        case "Clear": { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Overcast": { [0.5, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Foggy": { [0.3, 0, 0.5, 0.01, 0, 0, 0, 0, 0] };
        case "Rain": { [0.8, 0.5, 0.1, 0.01, 0, 0, 0, 0, 0] };
        case "Storm": { [1, 1, 0.2, 0.01, 0, 0, 0, 0, 0] };
        case "FaceMission": { [1, 1, 0.5, 0.01, 0, 0, 0, 0, 0] };
        default { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
    };
};

FAC_scenarioGui_weatherPresets = [
    ["Clear", "Clear"],
    ["Overcast", "Overcast"],
    ["Foggy", "Foggy"],
    ["Rain", "Rain"],
    ["Storm", "Storm"],
    ["Face Mission", "FaceMission"],
    ["Custom", "Custom"]
];

FAC_scenarioGui_scenarioContentIdcs = [
    60804, 60805, 60806, 60820, 60821, 60822, 60302,
    60830, 60831, 60832, 60833, 60834, 60835, 60836, 60837, 60838, 60839, 60840, 60841, 60842, 60843,
    60940, 60941, 60942,
    60844, 60845, 60846, 60847, 60848,
    60850, 60851, 60852, 60853, 60854, 60855, 60856, 60857, 60858, 60859, 60860, 60861, 60862
];

FAC_scenarioGui_factionsContentIdcs = [
    60910, 60911, 60912, 60913, 60914, 60915, 60916, 60917, 60918, 60919, 60920, 60921,
    60870, 60871, 60872, 60873, 60874, 60875, 60876, 60877, 60878, 60879, 60880,
    60881, 60882, 60883, 60884, 60885, 60886, 60887, 60888, 60889, 60890, 60891, 60892, 60893, 60894,
    60310, 60311, 60312
];

FAC_scenarioGui_adminContentIdcs = [60930, 60943, 60895, 60896, 60897, 60898, 60899, 60900, 60901];

FAC_scenarioGui_getFactionDisplayName = {
    params ["_faction"];
    if (_faction == "") exitWith { "Unknown" };
    if (!isNil "FAC_loadoutGui_getFactionDisplayName") exitWith { [_faction] call FAC_loadoutGui_getFactionDisplayName };
    private _dn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_dn != "") exitWith { _dn };
    (_faction splitString "_") joinString " "
};

FAC_scenarioGui_getFactionsForSide = {
    params ["_sideNum"];
    private _result = [];
    {
        private _faction = configName _x;
        if (getNumber (_x >> "side") == _sideNum) then {
            private _dn = getText (_x >> "displayName");
            if (_dn == "") then { _dn = _faction };
            _result pushBack [_faction, _dn];
        };
    } forEach ("true" configClasses (configFile >> "CfgFactionClasses"));
    _result = _result apply { [_x select 1, _x select 0] };
    _result sort true;
    _result = _result apply { [_x select 1, _x select 0] };
    _result
};

FAC_scenarioGui_adminCleanupButtonDefs = [
    ["makeZeus", 60895, "Make me Zeus"],
    ["removeMyZeus", 60896, "Remove my Zeus"],
    ["teleportAllToBase", 60897, "Teleport all players to HQ (teleportBase)"],
    ["stopAllMusic", 60898, "Stop all music (jukebox)"],
    ["abortAllMissions", 60899, "Abort all missions"],
    ["despawnCivilians", 60900, "Despawn civilians"],
    ["despawnOpfor", 60901, "Despawn OPFOR"]
];

FAC_scenarioGui_adminResetCleanupButtons = {
    private _display = findDisplay FAC_scenarioGui_IDD;
    if (isNull _display) exitWith {};
    {
        _x params ["_action", "_idc", "_text"];
        private _ctrl = _display displayCtrl _idc;
        if (!isNull _ctrl) then {
            _ctrl ctrlSetText _text;
            _ctrl ctrlSetTextColor [1, 1, 1, 1];
        };
    } forEach FAC_scenarioGui_adminCleanupButtonDefs;
};

FAC_scenarioGui_syncHeaderTabs = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_scenarioGui_tab", "scenario"];
    private _bS = _d displayCtrl 60810;
    private _bF = _d displayCtrl 60811;
    private _bA = _d displayCtrl 60812;
    if (isNull _bS || { isNull _bF } || { isNull _bA }) exitWith {};
    _bS ctrlSetBackgroundColor (if (_tab == "scenario") then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    _bF ctrlSetBackgroundColor (if (_tab == "factions") then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    _bA ctrlSetBackgroundColor (if (_tab == "admin") then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
};

FAC_scenarioGui_setTabVisibility = {
    params ["_tab"];
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _showS = (_tab == "scenario");
    private _showF = (_tab == "factions");
    private _showA = (_tab == "admin");
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showS } } forEach FAC_scenarioGui_scenarioContentIdcs;
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showF } } forEach FAC_scenarioGui_factionsContentIdcs;
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow _showA } } forEach FAC_scenarioGui_adminContentIdcs;
};

// Faction listboxes live on the Factions tab; when hidden (Scenario/Admin), lbCurSel is often -1. Store picks in missionNamespace
// on every list change and on load; Apply reads picks only — never trust lbCurSel while the lists may be hidden.
FAC_scenarioGui_commitFactionListToPick = {
    params ["_display", "_idc", "_fallback"];
    private _lb = _display displayCtrl _idc;
    if (isNull _lb) exitWith {};
    private _fac = _fallback;
    private _i = lbCurSel _lb;
    if (_i >= 0) then {
        private _data = _lb lbData _i;
        if (_data != "") then { _fac = _data };
    };
    if (_fac == "") exitWith {};
    switch _idc do {
        case 60311: { missionNamespace setVariable ["FAC_scenarioGui_pickFriendlyFaction", _fac] };
        case 60310: { missionNamespace setVariable ["FAC_scenarioGui_pickEnemyFaction", _fac] };
        case 60312: { missionNamespace setVariable ["FAC_scenarioGui_pickCivFaction", _fac] };
    };
};

// After lists become visible again, restore selection from stored picks (engine may reset list index while hidden).
FAC_scenarioGui_syncFactionListsFromPicks = {
    params ["_display"];
    {
        _x params ["_idc", "_pickVar", "_default"];
        private _lb = _display displayCtrl _idc;
        if (isNull _lb) exitWith {};
        private _want = missionNamespace getVariable [_pickVar, _default];
        private _sel = -1;
        private _n = lbSize _lb;
        for "_i" from 0 to (_n - 1) do {
            if (_sel < 0 && { (_lb lbData _i) == _want }) then { _sel = _i };
        };
        if (_sel < 0) then { _sel = 0 };
        if (_n > 0) then { _lb lbSetCurSel _sel };
    } forEach [
        [60311, "FAC_scenarioGui_pickFriendlyFaction", "BLU_F"],
        [60310, "FAC_scenarioGui_pickEnemyFaction", "OPF_F"],
        [60312, "FAC_scenarioGui_pickCivFaction", "CIV_F"]
    ];
};

FAC_scenarioGui_applyWeatherArrayToSliders = {
    params ["_display", "_w"];
    if (count _w < 9) exitWith {};
    _w params ["_oc", "_rn", "_fd", "_fde", "_fb", "_ws", "_wd", "_gs", "_wv"];
    private _slO = _display displayCtrl 60830;
    private _slR = _display displayCtrl 60832;
    private _slF = _display displayCtrl 60834;
    private _slWS = _display displayCtrl 60836;
    private _slWD = _display displayCtrl 60838;
    private _slG = _display displayCtrl 60840;
    private _slWv = _display displayCtrl 60842;
    if (!isNull _slO) then { _slO sliderSetRange [0, 1]; _slO sliderSetPosition _oc };
    if (!isNull _slR) then { _slR sliderSetRange [0, 1]; _slR sliderSetPosition _rn };
    if (!isNull _slF) then { _slF sliderSetRange [0, 1]; _slF sliderSetPosition _fd };
    if (!isNull _slWS) then { _slWS sliderSetRange [0, 1]; _slWS sliderSetPosition _ws };
    if (!isNull _slWD) then { _slWD sliderSetRange [0, 360]; _slWD sliderSetPosition _wd };
    if (!isNull _slG) then { _slG sliderSetRange [0, 1]; _slG sliderSetPosition _gs };
    if (!isNull _slWv) then { _slWv sliderSetRange [0, 1]; _slWv sliderSetPosition _wv };
    ["syncWeatherLabels", [_display]] call FAC_scenarioGui_fnc;
};

FAC_scenarioGui_syncWeatherLabels = {
    params ["_display"];
    private _fmtPct = {
        params ["_idcSl", "_idcLb", "_prefix"];
        private _sl = _display displayCtrl _idcSl;
        private _lb = _display displayCtrl _idcLb;
        if (isNull _sl || { isNull _lb }) exitWith {};
        private _p = sliderPosition _sl;
        if (_idcSl == 60838) then {
            _lb ctrlSetText format ["%1: %2 deg", _prefix, round _p];
        } else {
            _lb ctrlSetText format ["%1: %2%", _prefix, round (_p * 100)];
        };
    };
    [60830, 60831, "Overcast"] call _fmtPct;
    [60832, 60833, "Rain"] call _fmtPct;
    [60834, 60835, "Fog"] call _fmtPct;
    [60836, 60837, "Wind"] call _fmtPct;
    [60838, 60839, "Wind dir"] call _fmtPct;
    [60840, 60841, "Gusts"] call _fmtPct;
    [60842, 60843, "Waves"] call _fmtPct;
};

FAC_scenarioGui_readWeatherParamsFromSliders = {
    params ["_display"];
    private _g = { params ["_idc"]; sliderPosition (_display displayCtrl _idc) };
    [
        [60830] call _g,
        [60832] call _g,
        [60834] call _g,
        0.01,
        0,
        [60836] call _g,
        sliderPosition (_display displayCtrl 60838),
        [60840] call _g,
        [60842] call _g
    ]
};

// Compare preset to UI (fog decay/base at indices 3–4 may differ from slider reconstruction; ignore them)
FAC_scenarioGui_weatherParamsMatchPreset = {
    params ["_a", "_b", "_eps"];
    if (count _a < 9 || { count _b < 9 }) exitWith { false };
    private _ok = true;
    { if (abs ((_a select _x) - (_b select _x)) > _eps) then { _ok = false } } forEach [0, 1, 2, 5, 6, 7, 8];
    _ok
};

FAC_scenarioGui_selectPresetForCurrentSliders = {
    private _display = findDisplay FAC_scenarioGui_IDD;
    if (isNull _display) exitWith {};
    private _wl = _display displayCtrl 60302;
    if (isNull _wl) exitWith {};
    private _cur = [_display] call FAC_scenarioGui_readWeatherParamsFromSliders;
    private _customIdx = (lbSize _wl) - 1;
    private _eps = 0.02;
    private _found = -1;
    for "_i" from 0 to (_customIdx - 1) do {
        private _id = _wl lbData _i;
        private _preset = [_id] call FAC_scenarioGui_getWeatherParamsForPresetId;
        if ([_cur, _preset, _eps] call FAC_scenarioGui_weatherParamsMatchPreset) exitWith { _found = _i };
    };
    if (_found >= 0) then {
        _wl lbSetCurSel _found;
    } else {
        if (_customIdx >= 0) then { _wl lbSetCurSel _customIdx };
    };
};

FAC_scenarioGui_syncLimitGearBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _on = missionNamespace getVariable ["FAC_scenarioGui_limitGear", false];
    private _b0 = _d displayCtrl 60850;
    private _b1 = _d displayCtrl 60851;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (!_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncCivBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _on = missionNamespace getVariable ["FAC_scenarioGui_civs", true];
    private _b0 = _d displayCtrl 60852;
    private _b1 = _d displayCtrl 60853;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (!_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncCtbBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _on = missionNamespace getVariable ["FAC_scenarioGui_ctb", false];
    private _b0 = _d displayCtrl 60854;
    private _b1 = _d displayCtrl 60855;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (!_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncTimeScaleBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _s = missionNamespace getVariable ["FAC_scenarioGui_timeScale", 1];
    private _b1 = _d displayCtrl 60856;
    private _b5 = _d displayCtrl 60857;
    private _b25 = _d displayCtrl 60858;
    if (!isNull _b1 && { !isNull _b5 } && { !isNull _b25 }) then {
        _b1 ctrlSetBackgroundColor (if (_s == 1) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b5 ctrlSetBackgroundColor (if (_s == 5) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b25 ctrlSetBackgroundColor (if (_s == 25) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncTeleportBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _m = missionNamespace getVariable ["FAC_scenarioGui_tpMode", 0];
    private _b0 = _d displayCtrl 60859;
    private _b1 = _d displayCtrl 60860;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (_m == 0) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_m > 0) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncPatrolBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _on = missionNamespace getVariable ["FAC_scenarioGui_patrols", false];
    private _b0 = _d displayCtrl 60870;
    private _b1 = _d displayCtrl 60871;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (!_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncRoutingBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _on = missionNamespace getVariable ["FAC_scenarioGui_routing", false];
    private _b0 = _d displayCtrl 60874;
    private _b1 = _d displayCtrl 60875;
    if (!isNull _b0 && { !isNull _b1 }) then {
        _b0 ctrlSetBackgroundColor (if (!_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        _b1 ctrlSetBackgroundColor (if (_on) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
    };
};

FAC_scenarioGui_syncAAABtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _lvl = missionNamespace getVariable ["FAC_scenarioGui_aaa", "None"];
    private _map = [["None", 60876], ["Light", 60877], ["Medium", 60878], ["MANPADS", 60879], ["Heavy", 60880]];
    {
        _x params ["_name", "_idc"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetBackgroundColor (if (_name == _lvl) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        };
    } forEach _map;
};

FAC_scenarioGui_syncLauncherBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _v = missionNamespace getVariable ["FAC_scenarioGui_launcher", "Normal"];
    private _map = [["Normal", 60881], ["Reduced", 60882], ["Minimal", 60883], ["None", 60884]];
    {
        _x params ["_name", "_idc"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetBackgroundColor (if (_name == _v) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        };
    } forEach _map;
};

FAC_scenarioGui_syncOpforPopBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _v = missionNamespace getVariable ["FAC_scenarioGui_opforPop", "Normal"];
    private _map = [["Auto", 60885], ["VeryLow", 60886], ["Low", 60887], ["Normal", 60888], ["High", 60889], ["VeryHigh", 60890], ["Insane", 60891]];
    {
        _x params ["_name", "_idc"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetBackgroundColor (if (_name == _v) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        };
    } forEach _map;
};

FAC_scenarioGui_syncOpforAirBtns = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _v = missionNamespace getVariable ["FAC_scenarioGui_opforAir", "Off"];
    private _map = [["Off", 60892], ["Low", 60893], ["Medium", 60894]];
    {
        _x params ["_name", "_idc"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetBackgroundColor (if (_name == _v) then { FAC_scenarioGui_act } else { FAC_scenarioGui_inact });
        };
    } forEach _map;
};

FAC_scenarioGui_updateTimeDisplay = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _h = missionNamespace getVariable ["FAC_scenarioGui_hour", 12];
    _h = (round _h) max 0 min 23;
    private _t = _d displayCtrl 60821;
    if (!isNull _t) then {
        private _s = if (_h < 10) then { "0" + str _h } else { str _h };
        _t ctrlSetText (_s + "00");
    };
};

FAC_scenarioGui_updateTownsLabel = {
    private _d = findDisplay FAC_scenarioGui_IDD;
    if (isNull _d) exitWith {};
    private _sl = _d displayCtrl 60861;
    private _lb = _d displayCtrl 60862;
    if (isNull _sl || { isNull _lb }) exitWith {};
    private _z = 2 + round (sliderPosition _sl);
    _z = _z max 2 min 10;
    _lb ctrlSetText format ["Operation towns: %1", _z];
};

FAC_scenarioGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay FAC_scenarioGui_IDD;
    if (isNull _display && { !(_action in ["open", "headerRefresh"]) }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayScenario") then {
                systemChat "SCENARIO GUI: RESOURCE NOT FOUND.";
            };
        };

        case "setTab": {
            _params params [["_tab", "scenario"]];
            if !(_tab in ["scenario", "factions", "admin"]) then { _tab = "scenario" };
            missionNamespace setVariable ["FAC_scenarioGui_tab", _tab];
            [_tab] call FAC_scenarioGui_setTabVisibility;
            [] call FAC_scenarioGui_syncHeaderTabs;
            if (_tab == "factions") then {
                private _d = findDisplay FAC_scenarioGui_IDD;
                if (!isNull _d) then {
                    [_d] call FAC_scenarioGui_syncFactionListsFromPicks;
                    [_d, 60311, missionNamespace getVariable ["FAC_scenarioGui_pickFriendlyFaction", "BLU_F"]] call FAC_scenarioGui_commitFactionListToPick;
                    [_d, 60310, missionNamespace getVariable ["FAC_scenarioGui_pickEnemyFaction", "OPF_F"]] call FAC_scenarioGui_commitFactionListToPick;
                    [_d, 60312, missionNamespace getVariable ["FAC_scenarioGui_pickCivFaction", "CIV_F"]] call FAC_scenarioGui_commitFactionListToPick;
                };
            };
            if (_tab == "admin") then {
                missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
                missionNamespace setVariable ["FAC_scenario_adminConfirmGen", 0];
                [] call FAC_scenarioGui_adminResetCleanupButtons;
            };
        };

        case "onLoad": {
            private _d = _params param [0, displayNull];
            if (isNull _d) then { _d = findDisplay FAC_scenarioGui_IDD };
            if (isNull _d) exitWith {};
            uinamespace setVariable ["FAC_scenarioGui_fnc", FAC_scenarioGui_fnc];

            missionNamespace setVariable ["FAC_scenarioGui_hour", missionNamespace getVariable ["FADE_scenarioTime", 18]];
            missionNamespace setVariable ["FAC_scenarioGui_limitGear", missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]];
            missionNamespace setVariable ["FAC_scenarioGui_civs", missionNamespace getVariable ["FADE_civiliansEnabled", true]];
            missionNamespace setVariable ["FAC_scenarioGui_ctb", missionNamespace getVariable ["FADE_limitToCtbLoadouts", false]];
            private _ts = missionNamespace getVariable ["FADE_timeCompressionScale", 1];
            _ts = (_ts max 1) min 100;
            private _pick = 1;
            if (_ts == 5 || _ts == 25) then { _pick = _ts };
            if (_ts > 25) then { _pick = 25 };
            if (_ts > 5 && _ts < 25) then { _pick = 5 };
            missionNamespace setVariable ["FAC_scenarioGui_timeScale", _pick];
            missionNamespace setVariable ["FAC_scenarioGui_tpMode", missionNamespace getVariable ["FADE_teleportToPlayerMode", 0]];
            missionNamespace setVariable ["FAC_scenarioGui_patrols", missionNamespace getVariable ["FADE_scenarioPatrols", false]];
            missionNamespace setVariable ["FAC_scenarioGui_routing", (missionNamespace getVariable ["FADE_enemyRouting", 0]) > 0];
            missionNamespace setVariable ["FAC_scenarioGui_aaa", missionNamespace getVariable ["FADE_enemyAAALevel", "None"]];
            missionNamespace setVariable ["FAC_scenarioGui_launcher", missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"]];
            missionNamespace setVariable ["FAC_scenarioGui_opforPop", missionNamespace getVariable ["FADE_opforPopulationSetting", "Normal"]];
            missionNamespace setVariable ["FAC_scenarioGui_opforAir", missionNamespace getVariable ["FADE_opforAirSetting", "Off"]];

            [] call FAC_scenarioGui_updateTimeDisplay;

            private _wl = _d displayCtrl 60302;
            lbClear _wl;
            private _curWid = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
            private _wp = missionNamespace getVariable ["FADE_scenarioWeatherParams", []];
            {
                _x params ["_name", "_id"];
                private _idx = _wl lbAdd _name;
                _wl lbSetData [_idx, _id];
            } forEach FAC_scenarioGui_weatherPresets;

            if ((count _wp) >= 9) then {
                [_d, _wp] call FAC_scenarioGui_applyWeatherArrayToSliders;
                [] call FAC_scenarioGui_selectPresetForCurrentSliders;
            } else {
                private _arr = [_curWid] call FAC_scenarioGui_getWeatherParamsForPresetId;
                [_d, _arr] call FAC_scenarioGui_applyWeatherArrayToSliders;
                private _sel = 0;
                { if ((_x select 1) == _curWid) exitWith { _sel = _forEachIndex } } forEach FAC_scenarioGui_weatherPresets;
                _wl lbSetCurSel (_sel min ((lbSize _wl) - 1));
            };

            private _st = _d displayCtrl 60861;
            if (!isNull _st) then {
                private _z = missionNamespace getVariable ["FADE_operationZoneCount", 6];
                _z = (round _z) max 2 min 10;
                _st sliderSetRange [0, 8];
                _st sliderSetPosition (_z - 2);
            };
            [] call FAC_scenarioGui_updateTownsLabel;

            private _scenHelp = _d displayCtrl 60940;
            if (!isNull _scenHelp) then {
                _scenHelp ctrlSetStructuredText parseText (
                    "<t color='#c8d8e8' size='1'>" +
                    "Presets snap the weather sliders; moving a slider switches the list to <t color='#a8d8ff'>Custom</t>.<br/>" +
                    "<t color='#a8d8ff'>Apply and Close</t> commits time, weather, rules, and faction picks from this dialog.<br/>" +
                    "Enemy AI and spawn factions live under <t color='#a8d8ff'>Factions</t>; Zeus and cleanup under <t color='#a8d8ff'>Admin</t>." +
                    "</t>"
                );
            };

            private _sk = _d displayCtrl 60872;
            if (!isNull _sk) then {
                private _skv = missionNamespace getVariable ["FADE_enemySkill", 0.2];
                _sk sliderSetRange [0, 1];
                _sk sliderSetSpeed [0.05, 0.1];
                _sk sliderSetPosition ((_skv max 0) min 1);
                private _skl = _d displayCtrl 60873;
                if (!isNull _skl) then { _skl ctrlSetText format ["%1", (round (_skv * 100)) / 100] };
            };

            private _friendlyList = _d displayCtrl 60311;
            lbClear _friendlyList;
            private _friendlyFactions = [1] call FAC_scenarioGui_getFactionsForSide;
            private _currentFriendly = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
            private _friendlySel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _friendlyList lbAdd _dn;
                _friendlyList lbSetData [_idx, _faction];
                if (_faction == _currentFriendly) then { _friendlySel = _idx };
            } forEach _friendlyFactions;
            if (lbSize _friendlyList > 0) then { _friendlyList lbSetCurSel _friendlySel };

            private _enemyList = _d displayCtrl 60310;
            lbClear _enemyList;
            private _enemyFactions = [0] call FAC_scenarioGui_getFactionsForSide;
            private _currentEnemy = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
            private _enemySel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _enemyList lbAdd _dn;
                _enemyList lbSetData [_idx, _faction];
                if (_faction == _currentEnemy) then { _enemySel = _idx };
            } forEach _enemyFactions;
            if (lbSize _enemyList > 0) then { _enemyList lbSetCurSel _enemySel };

            private _civList = _d displayCtrl 60312;
            lbClear _civList;
            private _civFactions = [3] call FAC_scenarioGui_getFactionsForSide;
            private _currentCiv = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
            private _civSel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _civList lbAdd _dn;
                _civList lbSetData [_idx, _faction];
                if (_faction == _currentCiv) then { _civSel = _idx };
            } forEach _civFactions;
            if (lbSize _civList > 0) then { _civList lbSetCurSel _civSel };

            [_d, 60311, _currentFriendly] call FAC_scenarioGui_commitFactionListToPick;
            [_d, 60310, _currentEnemy] call FAC_scenarioGui_commitFactionListToPick;
            [_d, 60312, _currentCiv] call FAC_scenarioGui_commitFactionListToPick;

            [] call FAC_scenarioGui_syncLimitGearBtns;
            [] call FAC_scenarioGui_syncCivBtns;
            [] call FAC_scenarioGui_syncCtbBtns;
            [] call FAC_scenarioGui_syncTimeScaleBtns;
            [] call FAC_scenarioGui_syncTeleportBtns;
            [] call FAC_scenarioGui_syncPatrolBtns;
            [] call FAC_scenarioGui_syncRoutingBtns;
            [] call FAC_scenarioGui_syncAAABtns;
            [] call FAC_scenarioGui_syncLauncherBtns;
            [] call FAC_scenarioGui_syncOpforPopBtns;
            [] call FAC_scenarioGui_syncOpforAirBtns;

            ["setTab", ["scenario"]] call FAC_scenarioGui_fnc;
        };

        case "timeStep": {
            _params params [["_delta", 0]];
            private _h = missionNamespace getVariable ["FAC_scenarioGui_hour", 12];
            _h = ((_h + _delta + 24) % 24);
            missionNamespace setVariable ["FAC_scenarioGui_hour", _h];
            [] call FAC_scenarioGui_updateTimeDisplay;
        };

        case "factionListChanged": {
            _params params ["_idc"];
            private _d = findDisplay FAC_scenarioGui_IDD;
            if (isNull _d) exitWith {};
            private _fb = switch _idc do {
                case 60311: { missionNamespace getVariable ["FAC_scenarioGui_pickFriendlyFaction", "BLU_F"] };
                case 60310: { missionNamespace getVariable ["FAC_scenarioGui_pickEnemyFaction", "OPF_F"] };
                case 60312: { missionNamespace getVariable ["FAC_scenarioGui_pickCivFaction", "CIV_F"] };
                default { "BLU_F" };
            };
            [_d, _idc, _fb] call FAC_scenarioGui_commitFactionListToPick;
        };

        case "weatherPresetChanged": {
            private _d = findDisplay FAC_scenarioGui_IDD;
            if (isNull _d) exitWith {};
            private _wl = _d displayCtrl 60302;
            private _i = lbCurSel _wl;
            if (_i < 0) exitWith {};
            private _id = _wl lbData _i;
            if (_id == "Custom") exitWith {};
            private _arr = [_id] call FAC_scenarioGui_getWeatherParamsForPresetId;
            [_d, _arr] call FAC_scenarioGui_applyWeatherArrayToSliders;
        };

        case "sliderChanged": {
            _params params ["_ctrl", "_pos"];
            if (isNull _ctrl) exitWith {};
            private _d = ctrlParent _ctrl;
            if (isNull _d) exitWith {};
            private _idc = ctrlIDC _ctrl;
            if (_idc in [60830, 60832, 60834, 60836, 60838, 60840, 60842]) then {
                ["syncWeatherLabels", [_d]] call FAC_scenarioGui_fnc;
                [] call FAC_scenarioGui_selectPresetForCurrentSliders;
            };
            if (_idc == 60861) then {
                [] call FAC_scenarioGui_updateTownsLabel;
            };
            if (_idc == 60872) then {
                private _lb = _d displayCtrl 60873;
                if (!isNull _lb) then {
                    private _v = (sliderPosition _ctrl) max 0 min 1;
                    _lb ctrlSetText format ["%1", (round (_v * 20)) / 20];
                };
            };
        };

        case "syncWeatherLabels": {
            _params params ["_d"];
            [_d] call FAC_scenarioGui_syncWeatherLabels;
        };

        case "toggleLimitGear": {
            _params params ["_on"];
            missionNamespace setVariable ["FAC_scenarioGui_limitGear", _on];
            [] call FAC_scenarioGui_syncLimitGearBtns;
        };
        case "toggleCivs": {
            _params params ["_on"];
            missionNamespace setVariable ["FAC_scenarioGui_civs", _on];
            [] call FAC_scenarioGui_syncCivBtns;
        };
        case "toggleCtb": {
            _params params ["_on"];
            missionNamespace setVariable ["FAC_scenarioGui_ctb", _on];
            [] call FAC_scenarioGui_syncCtbBtns;
        };
        case "setTimeScale": {
            _params params ["_s"];
            missionNamespace setVariable ["FAC_scenarioGui_timeScale", _s];
            [] call FAC_scenarioGui_syncTimeScaleBtns;
        };
        case "setTeleportMode": {
            _params params ["_m"];
            missionNamespace setVariable ["FAC_scenarioGui_tpMode", _m];
            [] call FAC_scenarioGui_syncTeleportBtns;
        };
        case "togglePatrols": {
            _params params ["_on"];
            missionNamespace setVariable ["FAC_scenarioGui_patrols", _on];
            [] call FAC_scenarioGui_syncPatrolBtns;
        };
        case "toggleRouting": {
            _params params ["_on"];
            missionNamespace setVariable ["FAC_scenarioGui_routing", _on];
            [] call FAC_scenarioGui_syncRoutingBtns;
        };
        case "setAAA": {
            _params params ["_lvl"];
            missionNamespace setVariable ["FAC_scenarioGui_aaa", _lvl];
            [] call FAC_scenarioGui_syncAAABtns;
        };
        case "setLauncher": {
            _params params ["_v"];
            missionNamespace setVariable ["FAC_scenarioGui_launcher", _v];
            [] call FAC_scenarioGui_syncLauncherBtns;
        };
        case "setOpforPop": {
            _params params ["_v"];
            missionNamespace setVariable ["FAC_scenarioGui_opforPop", _v];
            [] call FAC_scenarioGui_syncOpforPopBtns;
        };
        case "setOpforAir": {
            _params params ["_v"];
            missionNamespace setVariable ["FAC_scenarioGui_opforAir", _v];
            [] call FAC_scenarioGui_syncOpforAirBtns;
        };

        case "headerRefresh": {
            private _d = findDisplay FAC_scenarioGui_IDD;
            if (!isNull _d) then { ["onLoad", [_d]] call FAC_scenarioGui_fnc };
        };

        case "adminCleanup": {
            if (isNull (findDisplay FAC_scenarioGui_IDD)) exitWith {};
            private _cleanupAction = (_params param [0, ""]) + "";
            if (_cleanupAction == "") exitWith {};
            private _display = findDisplay FAC_scenarioGui_IDD;
            private _state = missionNamespace getVariable ["FAC_scenario_adminPending", ["", -99]];
            private _pendingAction = _state param [0, ""];
            private _pendingTime = _state param [1, -99];
            if (_pendingAction != _cleanupAction || { time - _pendingTime > 3 }) then {
                private _confirmGen = (missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) + 1;
                missionNamespace setVariable ["FAC_scenario_adminConfirmGen", _confirmGen];
                missionNamespace setVariable ["FAC_scenario_adminPending", [_cleanupAction, time]];
                {
                    _x params ["_act", "_idc", "_txt"];
                    private _ctrl = _display displayCtrl _idc;
                    if (!isNull _ctrl) then {
                        if (_act == _cleanupAction) then {
                            _ctrl ctrlSetText "Are you sure?";
                            _ctrl ctrlSetTextColor [1, 0.35, 0.35, 1];
                        } else {
                            _ctrl ctrlSetText _txt;
                            _ctrl ctrlSetTextColor [1, 1, 1, 1];
                        };
                    };
                } forEach FAC_scenarioGui_adminCleanupButtonDefs;
                [_confirmGen] spawn {
                    params ["_gen"];
                    sleep 3;
                    if ((missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) != _gen) exitWith {};
                    private _st = missionNamespace getVariable ["FAC_scenario_adminPending", ["", -99]];
                    if ((_st param [0, ""]) != "") then {
                        missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
                        if (!isNull (findDisplay FAC_scenarioGui_IDD)) then {
                            [] call FAC_scenarioGui_adminResetCleanupButtons;
                        };
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_scenario_adminConfirmGen", (missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) + 1];
                missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
                [] call FAC_scenarioGui_adminResetCleanupButtons;
                [_cleanupAction, player] remoteExec ["FADE_adminCleanupAction", 2];
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
        };

        case "apply": {
            private _d = findDisplay FAC_scenarioGui_IDD;
            if (isNull _d) exitWith {};
            private _hour = missionNamespace getVariable ["FAC_scenarioGui_hour", 12];
            _hour = (round _hour) max 0 min 23;

            private _wl = _d displayCtrl 60302;
            private _weather = "Clear";
            if (lbCurSel _wl >= 0) then { _weather = _wl lbData (lbCurSel _wl) };

            private _friendlyFaction = missionNamespace getVariable ["FAC_scenarioGui_pickFriendlyFaction", missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"]];
            private _enemyFaction = missionNamespace getVariable ["FAC_scenarioGui_pickEnemyFaction", missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"]];
            private _civFaction = missionNamespace getVariable ["FAC_scenarioGui_pickCivFaction", missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"]];

            private _limitGear = missionNamespace getVariable ["FAC_scenarioGui_limitGear", false];
            private _ctbOnly = missionNamespace getVariable ["FAC_scenarioGui_ctb", false];
            private _patrolsEnabled = missionNamespace getVariable ["FAC_scenarioGui_patrols", false];
            private _enemySkill = sliderPosition (_d displayCtrl 60872);
            _enemySkill = (_enemySkill max 0) min 1;
            private _enemyRouting = if (missionNamespace getVariable ["FAC_scenarioGui_routing", false]) then { 0.5 } else { 0 };
            private _enemyAAA = missionNamespace getVariable ["FAC_scenarioGui_aaa", "None"];
            private _opforLauncherSetting = missionNamespace getVariable ["FAC_scenarioGui_launcher", "Normal"];
            private _opforAirSetting = missionNamespace getVariable ["FAC_scenarioGui_opforAir", "Off"];
            private _opforPopulationSetting = missionNamespace getVariable ["FAC_scenarioGui_opforPop", "Normal"];
            private _timeCompressionScale = missionNamespace getVariable ["FAC_scenarioGui_timeScale", 1];
            private _teleportToPlayerMode = missionNamespace getVariable ["FAC_scenarioGui_tpMode", 0];
            private _civiliansEnabled = missionNamespace getVariable ["FAC_scenarioGui_civs", true];

            private _slT = _d displayCtrl 60861;
            private _operationZoneCount = 6;
            if (!isNull _slT) then { _operationZoneCount = 2 + round (sliderPosition _slT) };
            _operationZoneCount = (round _operationZoneCount) max 2 min 10;

            private _aoStrength = missionNamespace getVariable ["FADE_aoStrength", "Medium"];
            if (_aoStrength == "Mid") then { _aoStrength = "Medium" };

            private _weatherParams = [_d] call FAC_scenarioGui_readWeatherParamsFromSliders;

            missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
            missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
            missionNamespace setVariable ["FADE_scenarioPatrols", _patrolsEnabled];
            missionNamespace setVariable ["FADE_enemySkill", _enemySkill];
            missionNamespace setVariable ["FADE_enemyRouting", _enemyRouting];
            missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
            missionNamespace setVariable ["FADE_opforPopulationSetting", _opforPopulationSetting];
            missionNamespace setVariable ["FADE_opforLauncherSetting", _opforLauncherSetting];
            missionNamespace setVariable ["FADE_opforAirSetting", _opforAirSetting];
            missionNamespace setVariable ["FADE_operationZoneCount", _operationZoneCount];
            missionNamespace setVariable ["FADE_timeCompressionScale", _timeCompressionScale];
            missionNamespace setVariable ["FADE_teleportToPlayerMode", _teleportToPlayerMode];
            missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
            missionNamespace setVariable ["FADE_limitToCtbLoadouts", _ctbOnly];

            private _scenarioApplyArgs = [
                _hour, _weather, _enemyFaction, _friendlyFaction, _civFaction, _limitGear, _ctbOnly, player,
                _patrolsEnabled, _enemySkill, _enemyRouting, _enemyAAA, _civiliansEnabled, _aoStrength,
                _timeCompressionScale, _opforPopulationSetting, _teleportToPlayerMode, _opforLauncherSetting,
                _opforAirSetting, _operationZoneCount, _weatherParams
            ];
            [_scenarioApplyArgs] remoteExec ["FADE_applyScenarioSettings", 2];
            closeDialog 0;
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};
