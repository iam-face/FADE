// =============================================================================
// RangeGui.sqf — firing / AT range terminal (client), idd 60920
// Two tabs: Range… (session + my settings) | Equipment… (one class list + pads rangeFriendlyVehPos_*).
// Full data refresh only: dialog onLoad, header Refresh, range session start (server),
// or FADE_rangeClient_setAtWeaponState after equipment spawn sync — not FAC_guiScheduleHeaderRefresh.
// =============================================================================
FAC_rangeGui_IDD = 60920;

FAC_rangeGui_getSlotDisplayName = {
    params ["_slotName"];
    private _names = missionNamespace getVariable ["FADE_rangeFriendlyVehPosNames", []];
    private _disp = missionNamespace getVariable ["FADE_rangeFriendlyVehPosDisplayNames", []];
    private _i = _names find _slotName;
    if (_i >= 0 && { count _disp > _i }) exitWith { _disp select _i };
    _slotName
};

FAC_rangeGui_tabRangeIdcs = [
    60962, 60923, 60970, 60934, 60935, 60966, 60967, 60928, 60929, 60968, 60930, 60931, 60969, 60932, 60933,
    60971, 60936, 60937, 60973, 60939, 60940, 60941, 60942, 60943, 60963, 60964, 60924, 60925, 60965, 60926, 60927,
    60938
];
FAC_rangeGui_tabEquipmentIdcs = [
    60993, 60982, 60983, 60989, 60949, 60990, 60950, 60984, 60951, 60952, 60948
];

FAC_rangeGui_syncMainTabs = {
    private _d = findDisplay FAC_rangeGui_IDD;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_rangeGui_tab", "range"];
    private _act = [0.22, 0.48, 0.78, 1];
    private _inact = [0.07, 0.11, 0.20, 1];
    (_d displayCtrl 60960) ctrlSetBackgroundColor (if (_tab == "range") then { _act } else { _inact });
    (_d displayCtrl 60978) ctrlSetBackgroundColor (if (_tab == "equipment") then { _act } else { _inact });
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
        private _prevV = if (lbCurSel _vl >= 0) then { _vl lbData (lbCurSel _vl) } else { "" };
        private _prevS = if (lbCurSel _sl >= 0) then { _sl lbData (lbCurSel _sl) } else { "" };
        private _full = missionNamespace getVariable ["FADE_rangeFriendlyLandListClient", []];
        private _q = toLower ctrlText (_d displayCtrl 60983);
        private _rows = if (_q == "") then { +_full } else {
            _full select {
                _x params ["_label", "_cls"];
                (((toLower _label) find _q) >= 0) || (((toLower _cls) find _q) >= 0)
            };
        };
        lbClear _vl;
        lbClear _sl;
        {
            _x params ["_label", "_cls"];
            private _i = _vl lbAdd _label;
            _vl lbSetData [_i, _cls];
        } forEach _rows;
        private _slotState = missionNamespace getVariable ["FADE_rangeFriendlySlotStateClient", []];
        {
            _x params ["_slot", "_state"];
            private _label = [_slot] call FAC_rangeGui_getSlotDisplayName;
            private _line = if (_state == "") then { format ["%1 — empty", _label] } else { format ["%1 — %2", _label, _state] };
            private _i = _sl lbAdd _line;
            _sl lbSetData [_i, _slot];
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
        [] call _refreshFriendlyPreview;
    };
    private _refreshInteractivity = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _active = missionNamespace getVariable ["FADE_rangeSessionActive", false];
        // Range tab: lock session settings while active; keep End session (60938) enabled.
        private _rangeIdcs = +FAC_rangeGui_tabRangeIdcs;
        _rangeIdcs = _rangeIdcs - [60938];
        { (_d displayCtrl _x) ctrlEnable (!_active) } forEach _rangeIdcs;
        if (_active) then { (_d displayCtrl 60938) ctrlEnable true };
        // Equipment tab: always editable (spawn/despawn pads during an active session).
    };
    private _refreshInfo = {
        private _d = findDisplay 60920; if (isNull _d) exitWith {};
        private _fp = missionNamespace getVariable ["FADE_rangeFiringPosCount", 0];
        private _fc = missionNamespace getVariable ["FADE_rangeFriendlyVehPosCount", 0];
        private _tab = missionNamespace getVariable ["FAC_rangeGui_tab", "range"];
        private _body = if (_tab == "equipment") then {
            format [
                "<t size='0.85' color='#c8d8e8'>Equipment pads: <t color='#ffffff'>%1</t> friendly equipment positions — spawn/despawn stays available during an active range session. Range session settings are on the Range tab (locked while active).</t>",
                _fc
            ]
        } else {
            format [
                "<t size='0.85' color='#c8d8e8'>Session pool: <t color='#ffffff'>%1</t> firing range positions (pop-ups, OPFOR, session vehicles). Equipment pads: <t color='#ffffff'>%2</t> friendly equipment positions (Equipment tab; usable while session active). " +
                "Projectile trace and impact markers: visible to all players; trace and new impact spheres auto-off &gt;100 m from terminal. " +
                "Targets face <t color='#ffffff'>terminalRange</t>. Max range 100–300 m (session + equipment).</t>",
                _fp, _fc
            ]
        };
        (_d displayCtrl 60948) ctrlSetStructuredText parseText _body;
    };

    if (_action == "open") exitWith {
        if (!createDialog "RscDisplayRange") then { systemChat "Range GUI: RESOURCE NOT FOUND."; };
    };

    private _display = findDisplay 60920;
    if (isNull _display) exitWith {};

    switch _action do {
        case "onLoad": {
            uinamespace setVariable ["FAC_rangeGui_fnc", FAC_rangeGui_fnc];
            missionNamespace setVariable ["FAC_rangeGui_fnc", FAC_rangeGui_fnc];
            uinamespace setVariable ["FAC_rangeGui_enemyType", "targets"];
            uinamespace setVariable ["FAC_rangeGui_humanCount", 10];
            uinamespace setVariable ["FAC_rangeGui_vehCount", 0];
            uinamespace setVariable ["FAC_rangeGui_maxRange", 200];
            uinamespace setVariable ["FAC_rangeGui_trace", false];
            uinamespace setVariable ["FAC_rangeGui_hitTrack", true];
            uinamespace setVariable ["FAC_rangeGui_mode", "firing"];
            uinamespace setVariable ["FAC_rangeGui_vehicleTypes", createHashMapFromArray [["car", true], ["truck", true], ["apc", true], ["tank", true]]];
            [player] remoteExec ["FADE_rangeRequestAtWeaponState", 2];
            [] call _refreshThreat;
            [] call _refreshTrace;
            [] call _refreshHit;
            [] call _refreshMode;
            [] call _refreshCounts;
            [] call _refreshVehTypeToggles;
            private _d0 = findDisplay FAC_rangeGui_IDD;
            if (!isNull _d0) then { (_d0 displayCtrl 60983) ctrlSetText "" };
            [] call _refreshFriendlyPanel;
            [] call _refreshStatus;
            [] call _refreshSessionBtn;
            [] call _refreshInteractivity;
            [] call _refreshInfo;
            private _t0 = missionNamespace getVariable ["FAC_rangeGui_tab", "range"];
            if (_t0 in ["opfor", "weapons", "friendly"]) then { _t0 = if (_t0 == "friendly") then { "equipment" } else { "range" } };
            missionNamespace setVariable ["FAC_rangeGui_tab", _t0];
            ["setTab", [_t0]] call FAC_rangeGui_fnc;
        };
        case "setTab": {
            _params params [["_tab", "range"]];
            if (_tab in ["opfor", "weapons", "friendly"]) then { _tab = if (_tab == "friendly") then { "equipment" } else { "range" } };
            if !(_tab in ["range", "equipment"]) then { _tab = "range" };
            missionNamespace setVariable ["FAC_rangeGui_tab", _tab];
            private _d = findDisplay FAC_rangeGui_IDD;
            if (isNull _d) exitWith {};
            private _isR = (_tab == "range");
            private _isE = (_tab == "equipment");
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isR };
            } forEach FAC_rangeGui_tabRangeIdcs;
            {
                private _c = _d displayCtrl _x;
                if (!isNull _c) then { _c ctrlShow _isE };
            } forEach FAC_rangeGui_tabEquipmentIdcs;
            [] call FAC_rangeGui_syncMainTabs;
            [] call _refreshSessionBtn;
            if (_isE) then {
                [] call _refreshFriendlyPanel;
                [] call _refreshInfo;
            } else {
                [] call _refreshCounts;
                [] call _refreshVehTypeToggles;
                [] call _refreshStatus;
                [] call _refreshInfo;
            };
        };
        case "friendlyVehSel": {
            [] call _refreshFriendlyPreview;
        };
        case "friendlySearchChanged": {
            [] call _refreshFriendlyPanel;
        };
        case "syncFromServerLists": {
            [] call _refreshFriendlyPanel;
            [] call _refreshInfo;
            [] call _refreshInteractivity;
        };
        case "headerRefresh": {
            [player] remoteExec ["FADE_rangeRequestAtWeaponState", 2];
            [] call _refreshThreat;
            [] call _refreshTrace;
            [] call _refreshHit;
            [] call _refreshMode;
            [] call _refreshCounts;
            [] call _refreshVehTypeToggles;
            [] call _refreshFriendlyPanel;
            [] call _refreshStatus;
            [] call _refreshSessionBtn;
            [] call _refreshInteractivity;
            [] call _refreshInfo;
            [] call FAC_rangeGui_syncMainTabs;
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
        case "equipmentSpawn": {
            private _vl = _display displayCtrl 60949;
            private _frSl = _display displayCtrl 60950;
            private _maxM = uinamespace getVariable ["FAC_rangeGui_maxRange", 200];
            private _firstEmptyIn = {
                params [["_rows", []]];
                private _out = "";
                { _x params ["_sn", "_st"]; if (_st == "" && {_out == ""}) then { _out = _sn } } forEach _rows;
                _out
            };
            private _slotFromList = {
                params ["_rows", "_lb", "_lbSel"];
                if (_lbSel < 0 || {lbSize _lb < 1}) exitWith { "" };
                private _sn = _lb lbData _lbSel;
                if (_sn == "") exitWith { "" };
                private _fi = _rows findIf { (_x select 0) == _sn };
                if (_fi < 0) exitWith { "" };
                private _st = (_rows select _fi) select 1;
                if (_st != "") exitWith { "__occupied__" };
                _sn
            };
            private _iv = lbCurSel _vl;
            if (_iv < 0 || {(_vl lbData _iv) == ""}) exitWith { systemChat "Select a vehicle or equipment class in the list."; };
            private _cls = _vl lbData _iv;
            private _frRows = missionNamespace getVariable ["FADE_rangeFriendlySlotStateClient", []];
            private _slotName = [_frRows, _frSl, lbCurSel _frSl] call _slotFromList;
            if (_slotName == "__occupied__") exitWith { systemChat "That pad is not empty. Despawn it or pick another row."; };
            if (_slotName == "") then {
                _slotName = [_frRows] call _firstEmptyIn;
            };
            if (_slotName == "") exitWith { systemChat "No empty equipment pad."; };
            [_slotName, _cls, player, _maxM] remoteExec ["FADE_rangeSpawnFriendlyLandAtSlot", 2];
        };
        case "equipmentDespawn": {
            private _frSl = _display displayCtrl 60950;
            private _ifr = lbCurSel _frSl;
            if (_ifr < 0) exitWith { systemChat "Select a pad row."; };
            private _snF = _frSl lbData _ifr;
            if (_snF == "") exitWith { systemChat "Select a pad row."; };
            [_snF, player] remoteExec ["FADE_rangeDespawnFriendlyLandAtSlot", 2];
        };
        case "session": {
            private _active = missionNamespace getVariable ["FADE_rangeSessionActive", false];
            if (_active) then {
                [player] remoteExec ["FADE_rangeEndSession", 2];
                closeDialog 0;
            } else {
                if (isNull player) exitWith { systemChat "Cannot start range (no player unit)."; };
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
        ["syncFromServerLists", []] call FAC_rangeGui_fnc;
    };
};
