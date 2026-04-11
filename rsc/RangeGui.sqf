// =============================================================================
// RangeGui.sqf — firing / AT range terminal (client), idd 60920
// Vehicle-GUI style: 3 tabs (Range | OPFOR/AT | Friendly) + Friendly sub-tabs Spawn / Slots
// =============================================================================
FAC_rangeGui_IDD = 60920;

FAC_rangeGui_tabRangeIdcs = [
    60962, 60923, 60963, 60964, 60924, 60925, 60965, 60926, 60927, 60966, 60967, 60928, 60929,
    60968, 60930, 60931, 60969, 60932, 60933, 60970, 60934, 60935, 60971, 60936, 60937, 60988
];
FAC_rangeGui_tabOpforIdcs = [
    60973, 60939, 60940, 60941, 60942, 60943, 60974, 60944, 60945, 60946, 60947, 60948
];
// Everything on Friendly tab (sub-tabs toggle spawn vs slots subsets)
FAC_rangeGui_tabFriendlyIdcs = [
    60979, 60980, 60972, 60982, 60983, 60989, 60949, 60990, 60950, 60984, 60951, 60991, 60987, 60952
];
FAC_rangeGui_friendlySpawnIdcs = [60982, 60983, 60989, 60949, 60990, 60950, 60984, 60951];
FAC_rangeGui_friendlySlotsIdcs = [60991, 60987, 60952];

FAC_rangeGui_syncMainTabs = {
    private _d = findDisplay FAC_rangeGui_IDD;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_rangeGui_tab", "range"];
    private _act = [0.22, 0.48, 0.78, 1];
    private _inact = [0.07, 0.11, 0.20, 1];
    (_d displayCtrl 60960) ctrlSetBackgroundColor (if (_tab == "range") then { _act } else { _inact });
    (_d displayCtrl 60961) ctrlSetBackgroundColor (if (_tab == "opfor") then { _act } else { _inact });
    (_d displayCtrl 60978) ctrlSetBackgroundColor (if (_tab == "friendly") then { _act } else { _inact });
};

FAC_rangeGui_syncFriendlySubTabs = {
    private _d = findDisplay FAC_rangeGui_IDD;
    if (isNull _d) exitWith {};
    private _sub = missionNamespace getVariable ["FAC_rangeGui_friendlySub", "spawn"];
    private _act = [0.22, 0.48, 0.78, 1];
    private _inact = [0.07, 0.11, 0.20, 1];
    (_d displayCtrl 60979) ctrlSetBackgroundColor (if (_sub == "spawn") then { _act } else { _inact });
    (_d displayCtrl 60980) ctrlSetBackgroundColor (if (_sub == "slots") then { _act } else { _inact });
};

FAC_rangeGui_fnc = {
    params ["_action", ["_params", []]];

    private _btnSel = [0.22, 0.48, 0.78, 1];
    private _btnIdle = [0.07, 0.11, 0.20, 1];

    private _refreshThreat = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _m = uinamespace getVariable ["FAC_rangeGui_enemyType", "targets"];
        (_d displayCtrl 60928) ctrlSetBackgroundColor (if (_m == "targets") then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60929) ctrlSetBackgroundColor (if (_m == "enemies") then { _btnSel } else { _btnIdle });
    };
    private _refreshTrace = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _on = uinamespace getVariable ["FAC_rangeGui_trace", false];
        (_d displayCtrl 60924) ctrlSetBackgroundColor (if (!_on) then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60925) ctrlSetBackgroundColor (if (_on) then { _btnSel } else { _btnIdle });
    };
    private _refreshHit = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _on = uinamespace getVariable ["FAC_rangeGui_hitTrack", true];
        (_d displayCtrl 60926) ctrlSetBackgroundColor (if (!_on) then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60927) ctrlSetBackgroundColor (if (_on) then { _btnSel } else { _btnIdle });
    };
    private _refreshMode = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _m = uinamespace getVariable ["FAC_rangeGui_mode", "firing"];
        (_d displayCtrl 60934) ctrlSetBackgroundColor (if (_m == "firing") then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60935) ctrlSetBackgroundColor (if (_m == "trial") then { _btnSel } else { _btnIdle });
    };
    private _refreshStatus = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _active = missionNamespace getVariable ["FADE_rangeSessionActive", false];
        private _s = _d displayCtrl 60923;
        if (_active) then {
            private _mode = missionNamespace getVariable ["FADE_rangeSessionMode", "firing"];
            private _txt = if (_mode == "trial") then { "ACTIVE — TIME TRIAL" } else { "ACTIVE — FIRING RANGE" };
            _s ctrlSetText _txt;
            _s ctrlSetTextColor [1, 0.82, 0.45, 1];
        } else {
            _s ctrlSetText "INACTIVE";
            _s ctrlSetTextColor [0.55, 0.95, 0.7, 1];
        };
    };
    private _refreshSessionBtn = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _btn = _d displayCtrl 60938;
        if (missionNamespace getVariable ["FADE_rangeSessionActive", false]) then {
            _btn ctrlSetText "End session";
            _btn ctrlSetBackgroundColor [0.55, 0.22, 0.14, 1];
        } else {
            _btn ctrlSetText "Start session";
            _btn ctrlSetBackgroundColor [0.22, 0.48, 0.78, 1];
        };
    };
    private _refreshCounts = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _hc = ((uinamespace getVariable ["FAC_rangeGui_humanCount", 10]) max 0) min 40;
        (_d displayCtrl 60931) sliderSetRange [0, 40];
        (_d displayCtrl 60931) sliderSetSpeed [1, 1];
        (_d displayCtrl 60931) sliderSetPosition _hc;
        (_d displayCtrl 60930) ctrlSetText str _hc;

        private _vc = ((uinamespace getVariable ["FAC_rangeGui_vehCount", 0]) max 0) min 10;
        (_d displayCtrl 60933) sliderSetRange [0, 10];
        (_d displayCtrl 60933) sliderSetSpeed [1, 1];
        (_d displayCtrl 60933) sliderSetPosition _vc;
        (_d displayCtrl 60932) ctrlSetText str _vc;

        private _mr = ((uinamespace getVariable ["FAC_rangeGui_maxRange", 200]) max 100) min 300;
        (_d displayCtrl 60937) sliderSetRange [100, 300];
        (_d displayCtrl 60937) sliderSetSpeed [10, 25];
        (_d displayCtrl 60937) sliderSetPosition _mr;
        (_d displayCtrl 60936) ctrlSetText format ["%1 m", _mr];
    };
    private _refreshVehTypeToggles = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _s = uinamespace getVariable ["FAC_rangeGui_vehicleTypes", createHashMapFromArray [["car", true], ["truck", true], ["apc", true], ["tank", true]]];
        (_d displayCtrl 60939) ctrlSetBackgroundColor (if (_s getOrDefault ["car", false]) then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60940) ctrlSetBackgroundColor (if (_s getOrDefault ["truck", false]) then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60941) ctrlSetBackgroundColor (if (_s getOrDefault ["apc", false]) then { _btnSel } else { _btnIdle });
        (_d displayCtrl 60942) ctrlSetBackgroundColor (if (_s getOrDefault ["tank", false]) then { _btnSel } else { _btnIdle });
    };
    private _refreshAtPanel = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _wl = _d displayCtrl 60944;
        private _sl = _d displayCtrl 60945;
        private _prevW = if (lbCurSel _wl >= 0) then { _wl lbData (lbCurSel _wl) } else { "" };
        private _prevS = if (lbCurSel _sl >= 0) then { _sl lbData (lbCurSel _sl) } else { "" };
        lbClear _wl;
        lbClear _sl;
        {
            _x params ["_label", "_cls"];
            private _i = _wl lbAdd _label;
            _wl lbSetData [_i, _cls];
        } forEach (missionNamespace getVariable ["FADE_rangeAtWeaponListClient", []]);
        {
            _x params ["_slot", "_state"];
            private _line = if (_state == "") then { format ["%1 — empty", _slot] } else { format ["%1 — %2", _slot, _state] };
            private _i = _sl lbAdd _line;
            _sl lbSetData [_i, _slot];
        } forEach (missionNamespace getVariable ["FADE_rangeAtSlotStateClient", []]);
        if (lbSize _wl > 0) then {
            private _wsel = 0;
            for "_i" from 0 to (lbSize _wl - 1) do { if ((_wl lbData _i) == _prevW) exitWith { _wsel = _i } };
            _wl lbSetCurSel _wsel;
        };
        if (lbSize _sl > 0) then {
            private _ssel = 0;
            for "_j" from 0 to (lbSize _sl - 1) do { if ((_sl lbData _j) == _prevS) exitWith { _ssel = _j } };
            _sl lbSetCurSel _ssel;
        };
    };
    private _refreshFriendlyPreview = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _pic = _d displayCtrl 60984;
        private _lb = _d displayCtrl 60949;
        private _idx = lbCurSel _lb;
        if (_idx < 0) exitWith { _pic ctrlSetText "" };
        private _cls = _lb lbData _idx;
        if (_cls == "") exitWith { _pic ctrlSetText "" };
        private _cfg = configFile >> "CfgVehicles" >> _cls;
        if (!isClass _cfg) exitWith { _pic ctrlSetText "" };
        private _tex = getText (_cfg >> "editorPreview");
        if (_tex == "") then { _tex = getText (_cfg >> "picture") };
        if (_tex == "") then { _tex = getText (_cfg >> "icon") };
        _pic ctrlSetText _tex;
    };
    private _refreshFriendlyPanel = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _vl = _d displayCtrl 60949;
        private _sl = _d displayCtrl 60950;
        private _ml = _d displayCtrl 60987;
        private _prevV = if (lbCurSel _vl >= 0) then { _vl lbData (lbCurSel _vl) } else { "" };
        private _prevS = if (lbCurSel _sl >= 0) then { _sl lbData (lbCurSel _sl) } else { "" };
        private _prevM = if (lbCurSel _ml >= 0) then { _ml lbData (lbCurSel _ml) } else { "" };
        private _full = missionNamespace getVariable ["FADE_rangeFriendlyLandListClient", []];
        private _q = toLower ctrlText (_d displayCtrl 60983);
        private _rows = if (_q == "") then { +_full } else {
            _full select {
                _x params ["_label", "_cls"];
                (toLower _label find _q >= 0) || { toLower _cls find _q >= 0 }
            };
        };
        lbClear _vl;
        lbClear _sl;
        lbClear _ml;
        {
            _x params ["_label", "_cls"];
            private _i = _vl lbAdd _label;
            _vl lbSetData [_i, _cls];
        } forEach _rows;
        private _slotState = missionNamespace getVariable ["FADE_rangeFriendlySlotStateClient", []];
        {
            _x params ["_slot", "_state"];
            private _line = if (_state == "") then { format ["%1 — empty", _slot] } else { format ["%1 — %2", _slot, _state] };
            private _i = _sl lbAdd _line;
            _sl lbSetData [_i, _slot];
        } forEach _slotState;
        {
            _x params ["_slot", "_state"];
            if (_state != "") then {
                private _line = format ["%1 — %2", _slot, _state];
                private _j = _ml lbAdd _line;
                _ml lbSetData [_j, _slot];
            };
        } forEach _slotState;
        if (lbSize _vl > 0) then {
            private _vsel = 0;
            for "_i" from 0 to (lbSize _vl - 1) do { if ((_vl lbData _i) == _prevV) exitWith { _vsel = _i } };
            _vl lbSetCurSel _vsel;
        };
        if (lbSize _sl > 0) then {
            private _ssel = 0;
            for "_j" from 0 to (lbSize _sl - 1) do { if ((_sl lbData _j) == _prevS) exitWith { _ssel = _j } };
            _sl lbSetCurSel _ssel;
        };
        if (lbSize _ml > 0) then {
            private _msel = 0;
            for "_k" from 0 to (lbSize _ml - 1) do { if ((_ml lbData _k) == _prevM) exitWith { _msel = _k } };
            _ml lbSetCurSel _msel;
        };
        [] call _refreshFriendlyPreview;
    };
    private _refreshInteractivity = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _active = missionNamespace getVariable ["FADE_rangeSessionActive", false];
        private _canEdit = !_active;
        {
            (_d displayCtrl _x) ctrlEnable _canEdit;
        } forEach [60924, 60925, 60926, 60927, 60928, 60929, 60931, 60933, 60934, 60935, 60937, 60939, 60940, 60941, 60942, 60983];
    };
    private _refreshInfo = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _hc = missionNamespace getVariable ["FADE_rangeHumanPosCount", 0];
        private _vc = missionNamespace getVariable ["FADE_rangeVehPosCount", 0];
        private _gc = missionNamespace getVariable ["FADE_rangeGunPosCount", 0];
        private _fc = missionNamespace getVariable ["FADE_rangeFriendlyVehPosCount", 0];
        (_d displayCtrl 60948) ctrlSetStructuredText parseText (
            format [
                "<t color='#c8d8e8'>Lanes: <t color='#ffffff'>%1</t> human (shootPos_*) · <t color='#ffffff'>%2</t> OPFOR veh (shootVehPos_*)<br/>" +
                "AT: <t color='#ffffff'>%3</t> (rangeGunPos_*) · Friendly: <t color='#ffffff'>%4</t> (rangeFriendlyVehPos_*)<br/><br/>" +
                "OPFOR session vehicles: random heading, engine on. Max spawn distance (Range tab, 100–300 m) applies to session lanes and slot spawns.</t>",
                _hc, _vc, _gc, _fc
            ]
        );
    };

    if (_action == "open") exitWith {
        if (!createDialog "RscDisplayRange") then { systemChat "Range GUI: RESOURCE NOT FOUND."; };
    };

    private _display = findDisplay 60920;
    if (isNull _display) exitWith {};

    switch _action do {
        case "onLoad": {
            uinamespace setVariable ["FAC_rangeGui_fnc", FAC_rangeGui_fnc];
            uinamespace setVariable ["FAC_rangeGui_enemyType", "targets"];
            uinamespace setVariable ["FAC_rangeGui_humanCount", 10];
            uinamespace setVariable ["FAC_rangeGui_vehCount", 0];
            uinamespace setVariable ["FAC_rangeGui_maxRange", 200];
            uinamespace setVariable ["FAC_rangeGui_trace", false];
            uinamespace setVariable ["FAC_rangeGui_hitTrack", true];
            uinamespace setVariable ["FAC_rangeGui_mode", "firing"];
            uinamespace setVariable ["FAC_rangeGui_vehicleTypes", createHashMapFromArray [["car", true], ["truck", true], ["apc", true], ["tank", true]]];
            missionNamespace setVariable ["FAC_rangeGui_friendlySub", "spawn"];
            [player] remoteExec ["FADE_rangeRequestAtWeaponState", 2];
            [] call _refreshThreat;
            [] call _refreshTrace;
            [] call _refreshHit;
            [] call _refreshMode;
            [] call _refreshCounts;
            [] call _refreshVehTypeToggles;
            [] call _refreshAtPanel;
            private _d0 = findDisplay FAC_rangeGui_IDD;
            if (!isNull _d0) then { (_d0 displayCtrl 60983) ctrlSetText "" };
            [] call _refreshFriendlyPanel;
            [] call _refreshStatus;
            [] call _refreshSessionBtn;
            [] call _refreshInteractivity;
            [] call _refreshInfo;
            private _t0 = missionNamespace getVariable ["FAC_rangeGui_tab", "range"];
            if (_t0 == "weapons") then { _t0 = "opfor" };
            missionNamespace setVariable ["FAC_rangeGui_tab", _t0];
            ["setTab", [_t0]] call FAC_rangeGui_fnc;
        };
        case "setTab": {
            _params params [["_tab", "range"]];
            if (_tab == "weapons") then { _tab = "opfor" };
            if !(_tab in ["range", "opfor", "friendly"]) then { _tab = "range" };
            missionNamespace setVariable ["FAC_rangeGui_tab", _tab];
            private _d = findDisplay FAC_rangeGui_IDD;
            if (isNull _d) exitWith {};
            private _isR = (_tab == "range");
            private _isO = (_tab == "opfor");
            private _isF = (_tab == "friendly");
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isR };
            } forEach FAC_rangeGui_tabRangeIdcs;
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isO };
            } forEach FAC_rangeGui_tabOpforIdcs;
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isF };
            } forEach FAC_rangeGui_tabFriendlyIdcs;
            private _sess = _d displayCtrl 60938;
            if (!isNull _sess) then { _sess ctrlShow true };
            [] call FAC_rangeGui_syncMainTabs;
            [] call _refreshSessionBtn;
            if (_isF) then {
                ["setFriendlySub", [missionNamespace getVariable ["FAC_rangeGui_friendlySub", "spawn"]]] call FAC_rangeGui_fnc;
                [] call _refreshFriendlyPanel;
            } else {
                [] call _refreshCounts;
                [] call _refreshVehTypeToggles;
                [] call _refreshAtPanel;
            };
        };
        case "setFriendlySub": {
            _params params [["_sub", "spawn"]];
            if !(_sub in ["spawn", "slots"]) then { _sub = "spawn" };
            missionNamespace setVariable ["FAC_rangeGui_friendlySub", _sub];
            private _d = findDisplay FAC_rangeGui_IDD;
            if (isNull _d) exitWith {};
            private _spawn = (_sub == "spawn");
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _spawn };
            } forEach FAC_rangeGui_friendlySpawnIdcs;
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow (!_spawn) };
            } forEach FAC_rangeGui_friendlySlotsIdcs;
            [] call FAC_rangeGui_syncFriendlySubTabs;
            if (_spawn) then { [] call _refreshFriendlyPreview };
        };
        case "friendlyVehSel": {
            [] call _refreshFriendlyPreview;
        };
        case "friendlySearchChanged": {
            [] call _refreshFriendlyPanel;
        };
        case "headerRefresh": {
            [player] remoteExec ["FADE_rangeRequestAtWeaponState", 2];
            [] call _refreshThreat;
            [] call _refreshTrace;
            [] call _refreshHit;
            [] call _refreshMode;
            [] call _refreshCounts;
            [] call _refreshVehTypeToggles;
            [] call _refreshAtPanel;
            [] call _refreshFriendlyPanel;
            [] call _refreshStatus;
            [] call _refreshSessionBtn;
            [] call _refreshInteractivity;
            [] call _refreshInfo;
            [] call FAC_rangeGui_syncMainTabs;
            [] call FAC_rangeGui_syncFriendlySubTabs;
        };
        case "setThreat": {
            uinamespace setVariable ["FAC_rangeGui_enemyType", _params param [0, "targets"]];
            [] call _refreshThreat;
        };
        case "setTrace": {
            uinamespace setVariable ["FAC_rangeGui_trace", _params param [0, false]];
            [] call _refreshTrace;
        };
        case "setHitTrack": {
            uinamespace setVariable ["FAC_rangeGui_hitTrack", _params param [0, true]];
            [] call _refreshHit;
        };
        case "setMode": {
            uinamespace setVariable ["FAC_rangeGui_mode", _params param [0, "firing"]];
            [] call _refreshMode;
        };
        case "setHumanCount": {
            uinamespace setVariable ["FAC_rangeGui_humanCount", ((round (_params param [0, 10])) max 0) min 40];
            [] call _refreshCounts;
        };
        case "setVehCount": {
            uinamespace setVariable ["FAC_rangeGui_vehCount", ((round (_params param [0, 0])) max 0) min 10];
            [] call _refreshCounts;
        };
        case "setMaxRange": {
            uinamespace setVariable ["FAC_rangeGui_maxRange", ((round (_params param [0, 200])) max 100) min 300];
            [] call _refreshCounts;
        };
        case "toggleVehType": {
            private _k = toLower (_params param [0, "car"]);
            private _s = uinamespace getVariable ["FAC_rangeGui_vehicleTypes", createHashMap];
            _s set [_k, !(_s getOrDefault [_k, false])];
            uinamespace setVariable ["FAC_rangeGui_vehicleTypes", _s];
            [] call _refreshVehTypeToggles;
        };
        case "spawnAtWeapon": {
            private _wl = _display displayCtrl 60944;
            private _sl = _display displayCtrl 60945;
            private _iw = lbCurSel _wl;
            private _is = lbCurSel _sl;
            if (_iw < 0 || {_is < 0}) exitWith { systemChat "Select an AT weapon and slot."; };
            private _weaponClass = _wl lbData _iw;
            private _slotName = _sl lbData _is;
            private _maxM = uinamespace getVariable ["FAC_rangeGui_maxRange", 200];
            [_slotName, _weaponClass, player, _maxM] remoteExec ["FADE_rangeSpawnAtWeaponAtSlot", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
        case "despawnAtWeapon": {
            private _sl = _display displayCtrl 60945;
            private _is = lbCurSel _sl;
            if (_is < 0) exitWith { systemChat "Select an AT slot."; };
            private _slotName = _sl lbData _is;
            [_slotName, player] remoteExec ["FADE_rangeDespawnAtWeaponSlot", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
        case "spawnFriendlyVeh": {
            private _vl = _display displayCtrl 60949;
            private _sl = _display displayCtrl 60950;
            private _iv = lbCurSel _vl;
            private _is = lbCurSel _sl;
            if (_iv < 0 || {_is < 0}) exitWith { systemChat "Select a friendly vehicle class and slot."; };
            private _cls = _vl lbData _iv;
            private _slotName = _sl lbData _is;
            private _maxM = uinamespace getVariable ["FAC_rangeGui_maxRange", 200];
            [_slotName, _cls, player, _maxM] remoteExec ["FADE_rangeSpawnFriendlyLandAtSlot", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
        case "despawnFriendlyVeh": {
            private _ml = _display displayCtrl 60987;
            private _is = lbCurSel _ml;
            if (_is < 0) exitWith { systemChat "Select a friendly vehicle slot."; };
            private _slotName = _ml lbData _is;
            [_slotName, player] remoteExec ["FADE_rangeDespawnFriendlyLandAtSlot", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
        case "session": {
            private _active = missionNamespace getVariable ["FADE_rangeSessionActive", false];
            if (_active) then {
                [player] remoteExec ["FADE_rangeEndSession", 2];
                closeDialog 0;
            } else {
                private _vehState = uinamespace getVariable ["FAC_rangeGui_vehicleTypes", createHashMap];
                private _vehTypes = [
                    _vehState getOrDefault ["car", false],
                    _vehState getOrDefault ["truck", false],
                    _vehState getOrDefault ["apc", false],
                    _vehState getOrDefault ["tank", false]
                ];
                [
                    player,
                    uinamespace getVariable ["FAC_rangeGui_enemyType", "targets"],
                    uinamespace getVariable ["FAC_rangeGui_humanCount", 10],
                    uinamespace getVariable ["FAC_rangeGui_vehCount", 0],
                    _vehTypes,
                    uinamespace getVariable ["FAC_rangeGui_maxRange", 200],
                    uinamespace getVariable ["FAC_rangeGui_trace", false],
                    uinamespace getVariable ["FAC_rangeGui_hitTrack", true],
                    uinamespace getVariable ["FAC_rangeGui_mode", "firing"]
                ] remoteExec ["FADE_rangeStartSession", 2];
                closeDialog 0;
            };
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};

FADE_rangeClient_setAtWeaponState = {
    params [["_weaponList", []], ["_slotState", []], ["_friendlyLandList", []], ["_friendlySlotState", []]];
    missionNamespace setVariable ["FADE_rangeAtWeaponListClient", +_weaponList];
    missionNamespace setVariable ["FADE_rangeAtSlotStateClient", +_slotState];
    missionNamespace setVariable ["FADE_rangeFriendlyLandListClient", +_friendlyLandList];
    missionNamespace setVariable ["FADE_rangeFriendlySlotStateClient", +_friendlySlotState];
    if (!isNull (findDisplay 60920)) then {
        ["headerRefresh", []] call FAC_rangeGui_fnc;
    };
};
