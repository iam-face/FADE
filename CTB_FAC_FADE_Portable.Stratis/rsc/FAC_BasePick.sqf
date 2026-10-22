// =============================================================================
// FAC_BasePick.sqf — client join screen, map click, confirm dialog, and vote dialog
// Compiled at the start of initPlayerLocal, before the server-ready wait.
// =============================================================================

// "" when the point can be the player base. Otherwise the sentence to show the player.
FAC_basePick_rejectReason = {
    params ["_pos"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { "That point is not on the map." };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || { !(_y isEqualType 0) }) exitWith { "That point is not on the map." };
    if (!finite _x || { !finite _y }) exitWith { "That point is not on the map." };
    if (surfaceIsWater [_x, _y]) exitWith { "That point is in the water." };
    private _minX = missionNamespace getVariable ["FADE_mapMinX", 0];
    private _maxX = missionNamespace getVariable ["FADE_mapMaxX", worldSize];
    private _minY = missionNamespace getVariable ["FADE_mapMinY", 0];
    private _maxY = missionNamespace getVariable ["FADE_mapMaxY", worldSize];
    if (!((_x >= _minX) && { _x <= _maxX } && { _y >= _minY } && { _y <= _maxY })) exitWith {
        "That point is off the map."
    };
    ""
};

FAC_basePick_posOk = {
    params ["_pos"];
    ([_pos] call FAC_basePick_rejectReason) == ""
};

FAC_basePick_clearMap = {
    onMapSingleClick (str false);
};

FAC_basePick_closeUi = {
    if (!hasInterface) exitWith {};
    missionNamespace setVariable ["FAC_basePick_mapLocked", false];
    [] call FAC_basePick_hideWait;
    [] call FAC_basePick_clearMap;
    hintSilent "";
    private _confirm = findDisplay 60960;
    if (!isNull _confirm) then { _confirm closeDisplay 1 };
    private _vote = findDisplay 60961;
    if (!isNull _vote) then { _vote closeDisplay 1 };
    openMap false;
    missionNamespace setVariable ["FAC_basePick_hintLoop", false];
};

// Block ShowMap and Escape while a point is being chosen, and reopen the map if it closes.
FAC_basePick_bindMapLock = {
    if (!hasInterface) exitWith {};
    private _disp = findDisplay 12;
    if (isNull _disp) exitWith {};
    if (_disp getVariable ["FAC_basePick_lockBound", false]) exitWith {};
    _disp setVariable ["FAC_basePick_lockBound", true];
    _disp displayAddEventHandler ["KeyDown", {
        params ["", "_key"];
        if !(missionNamespace getVariable ["FAC_basePick_mapLocked", false]) exitWith { false };
        private _block = actionKeys "ShowMap";
        if !(_block isEqualType []) then { _block = [] };
        _key in _block || { _key == 1 }
    }];
};

FAC_basePick_lockMap = {
    if (!hasInterface) exitWith {};
    missionNamespace setVariable ["FAC_basePick_mapLocked", true];
    [] call FAC_basePick_bindMapLock;
    if (missionNamespace getVariable ["FAC_basePick_lockLoop", false]) exitWith {};
    missionNamespace setVariable ["FAC_basePick_lockLoop", true];
    [] spawn {
        private _main = findDisplay 46;
        if (!isNull _main && { !(_main getVariable ["FAC_basePick_lockBound", false]) }) then {
            _main setVariable ["FAC_basePick_lockBound", true];
            _main displayAddEventHandler ["KeyDown", {
                params ["", "_key"];
                if !(missionNamespace getVariable ["FAC_basePick_mapLocked", false]) exitWith { false };
                if (!visibleMap) exitWith { false };
                private _block = actionKeys "ShowMap";
                if !(_block isEqualType []) then { _block = [] };
                _key in _block || { _key == 1 }
            }];
        };
        while { missionNamespace getVariable ["FAC_basePick_mapLocked", false] } do {
            if (missionNamespace getVariable ["FAC_basePick_mapLocked", false] && { !visibleMap }) then {
                openMap true;
            };
            [] call FAC_basePick_bindMapLock;
            if ((missionNamespace getVariable ["FADE_basePickPhase", ""]) == "vote" && { isNull findDisplay 60961 }) then {
                createDialog "RscDisplayBasePickVote";
            };
            sleep 0.1;
        };
        missionNamespace setVariable ["FAC_basePick_lockLoop", false];
    };
};

FAC_basePick_armMap = {
    params ["_hintText"];
    if (!hasInterface) exitWith {};
    [] call FAC_basePick_clearMap;
    // _pos exists only in this string. `_pos call fn` unpacks X into params and every click fails as water.
    // Store it, then call the handler. Same pattern as FADE_MapClickPick.sqf.
    onMapSingleClick "missionNamespace setVariable ['FAC_basePick_clickPos', _pos]; if (!isNil 'FAC_basePick_onMapClick') then { call FAC_basePick_onMapClick }; true";
    if (!visibleMap) then { openMap true };
    [] call FAC_basePick_lockMap;
    hint _hintText;
};

FAC_basePick_onMapClick = {
    if (!hasInterface) exitWith {};
    if (!isNull findDisplay 60960) exitWith {};
    private _pos = missionNamespace getVariable ["FAC_basePick_clickPos", []];
    private _phase = missionNamespace getVariable ["FADE_basePickPhase", ""];
    private _why = [_pos] call FAC_basePick_rejectReason;
    if (_why != "") exitWith {
        hint _why;
        systemChat _why;
    };
    if (_phase == "admin") exitWith {
        missionNamespace setVariable ["FAC_basePick_pendingPos", _pos];
        createDialog "RscDisplayBasePickConfirm";
    };
    if (_phase == "suggest") exitWith {
        [player, _pos] remoteExec ["FADE_basePick_suggest", 2];
        missionNamespace setVariable ["FAC_basePick_marked", true];
        hint format ["Marked %1. The team votes on the marked points when the timer ends.", mapGridPosition _pos];
    };
};

FAC_basePick_iAmAdmin = {
    private _uid = getPlayerUID player;
    private _list = missionNamespace getVariable ["FADE_basePick_adminUids", []];
    _uid != "" && { _uid in _list }
};

FAC_basePick_startHintLoop = {
    params ["_intro"];
    missionNamespace setVariable ["FAC_basePick_hintLoop", true];
    private _gen = missionNamespace getVariable ["FAC_basePick_hintGen", 0];
    _gen = _gen + 1;
    missionNamespace setVariable ["FAC_basePick_hintGen", _gen];
    [_intro, _gen] spawn {
        params ["_intro", "_gen"];
        while {
            missionNamespace getVariable ["FAC_basePick_hintLoop", false]
            && { (missionNamespace getVariable ["FAC_basePick_hintGen", 0]) == _gen }
        } do {
            private _left = ceil ((missionNamespace getVariable ["FADE_basePick_deadline", serverTime]) - serverTime);
            if (_left < 0) then { _left = 0 };
            private _marked = if (missionNamespace getVariable ["FAC_basePick_marked", false]) then {
                format ["Your point is marked.%1", toString [10]]
            } else {
                ""
            };
            hint format ["%1%2%3%4 s left.", _intro, toString [10], _marked, _left];
            sleep 1;
        };
    };
};

FAC_basePick_waitHtml = {
    private _deadline = missionNamespace getVariable ["FADE_basePick_deadline", -1];
    private _clock = "";
    if (_deadline isEqualType 0 && { _deadline > 0 }) then {
        private _left = ceil (_deadline - serverTime);
        if (_left < 0) then { _left = 0 };
        _clock = format ["<br/><br/><t align='center' size='1.35'>%1 s</t>", _left];
    };
    format [
        "<t align='center' size='1.15'>Waiting for players to initialise.</t><br/><br/><t align='center' size='1.05'>Next, mark a point on the map for the player base.</t>%1",
        _clock
    ]
};

FAC_basePick_setWaitText = {
    params [["_d", displayNull]];
    if (isNull _d) then { _d = findDisplay 60962 };
    if (isNull _d) exitWith {};
    private _ctrl = _d displayCtrl 60990;
    if (isNull _ctrl) exitWith {};
    _ctrl ctrlSetStructuredText parseText ([] call FAC_basePick_waitHtml);
};

FAC_basePick_hideWait = {
    if (!hasInterface) exitWith {};
    if !(missionNamespace getVariable ["FAC_basePick_waitOn", false]) exitWith {};
    missionNamespace setVariable ["FAC_basePick_waitOn", false];
    private _wait = findDisplay 60962;
    if (!isNull _wait) then { _wait closeDisplay 1 };
    showHUD [true, true, true, true, true, true, true, true, true, true, false];
};

FAC_basePick_showWait = {
    if (!hasInterface) exitWith {};
    if (worldName == "Altis") exitWith {};
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith {};
    if (missionNamespace getVariable ["FAC_basePick_waitOn", false]) exitWith {};
    missionNamespace setVariable ["FAC_basePick_waitOn", true];
    showHUD [true, false, false, false, false, false, false, false, false, false, false];
    if (isNull findDisplay 60962) then { createDialog "RscDisplayBasePickWait" };
    [] spawn {
        while { missionNamespace getVariable ["FAC_basePick_waitOn", false] } do {
            private _d = findDisplay 60962;
            if (isNull _d) then {
                createDialog "RscDisplayBasePickWait";
            } else {
                [_d] call FAC_basePick_setWaitText;
            };
            sleep 0.25;
        };
    };
};

// findDisplay is null while onLoad is running. Pass the display from onLoad, then fill again once the dialog is open.
FAC_basePick_fillVoteList = {
    params [["_d", displayNull]];
    if (!hasInterface) exitWith {};
    if (isNull _d) then { _d = findDisplay 60961 };
    if (isNull _d) exitWith {};
    private _list = _d displayCtrl 60980;
    if (isNull _list) exitWith {};
    lbClear _list;
    {
        if (_x isEqualType [] && { count _x >= 4 }) then {
            private _uid = _x select 0;
            private _nm = _x select 1;
            private _px = _x select 2;
            private _py = _x select 3;
            if (_uid isEqualType "" && { _nm isEqualType "" } && { _px isEqualType 0 } && { _py isEqualType 0 }) then {
                private _grid = mapGridPosition [_px, _py];
                if ((count _grid) >= 4 && { ((count _grid) mod 2) == 0 }) then {
                    private _half = (count _grid) / 2;
                    private _digits = true;
                    for "_i" from 0 to ((count _grid) - 1) do {
                        if !((_grid select [_i, 1]) in ["0","1","2","3","4","5","6","7","8","9"]) exitWith { _digits = false };
                    };
                    if (_digits) then { _grid = format ["%1 %2", _grid select [0, _half], _grid select [_half, _half]] };
                };
                private _row = _list lbAdd format ["%1, grid %2", _nm, _grid];
                _list lbSetData [_row, _uid];
            };
        };
    } forEach (missionNamespace getVariable ["FADE_basePick_choiceList", []]);
    if ((lbSize _list) > 0) then { _list lbSetCurSel 0 };
};

FAC_basePick_showDeploy = {
    params [["_line", ""]];
    if (!hasInterface) exitWith {};
    if (missionNamespace getVariable ["FAC_basePick_deployOn", false]) exitWith {};
    missionNamespace setVariable ["FAC_basePick_deployOn", true];
    missionNamespace setVariable ["FAC_basePick_mapLocked", false];
    [_line] spawn {
        params ["_line"];
        showHUD [true, false, false, false, false, false, false, false, false, false, false];
        cutText ["", "BLACK OUT", 1];
        private _fadeDone = time + 1;
        waitUntil {
            if (_line == "") then {
                _line = missionNamespace getVariable ["FADE_basePick_deployLine", ""];
            };
            sleep 0.05;
            time >= _fadeDone
        };
        [] call FAC_basePick_closeUi;
        if (_line != "") then {
            if (isNull findDisplay 60963) then { createDialog "RscDisplayBasePickDeploy" };
            private _ctrl = (findDisplay 60963) displayCtrl 60991;
            if (!isNull _ctrl) then {
                private _safe = _line;
                {
                    _safe = (_safe splitString (_x select 0)) joinString (_x select 1);
                } forEach [["&", "&amp;"], ["<", "&lt;"], [">", "&gt;"]];
                _ctrl ctrlSetStructuredText parseText format ["<t align='center' size='1.15'>%1</t>", _safe];
            };
            sleep 3.5;
            private _card = findDisplay 60963;
            if (!isNull _card) then { _card closeDisplay 1 };
        };
        cutText ["", "BLACK IN", 1];
        showHUD [true, true, true, true, true, true, true, true, true, true, false];
        missionNamespace setVariable ["FAC_basePick_deployOn", false];
    };
};

FAC_basePick_applyPhase = {
    params [["_phase", ""], ["_choiceList", []]];
    if (_choiceList isEqualType [] && { count _choiceList > 0 }) then {
        missionNamespace setVariable ["FADE_basePick_choiceList", _choiceList];
    };
    if (!hasInterface) exitWith {};
    if (isNull player) exitWith {};
    if (_phase == "") then { _phase = missionNamespace getVariable ["FADE_basePickPhase", ""] };
    switch (_phase) do {
        case "waiting": {
            [] call FAC_basePick_showWait;
        };
        case "admin": {
            [] call FAC_basePick_closeUi;
            if ([] call FAC_basePick_iAmAdmin) then {
                ["Click dry ground on the map to place the player base."] call FAC_basePick_armMap;
            } else {
                hint "An admin is placing the player base.";
            };
        };
        case "adminLeft": {
            [] call FAC_basePick_closeUi;
            hint "The admin left. Mark a point on the map.";
        };
        case "suggest": {
            [] call FAC_basePick_hideWait;
            missionNamespace setVariable ["FAC_basePick_marked", false];
            private _vote = findDisplay 60961;
            if (!isNull _vote) then { _vote closeDisplay 1 };
            private _intro = format [
                "The team is choosing the player base.%1Click dry ground on the map to mark your point.",
                toString [10]
            ];
            [_intro] call FAC_basePick_armMap;
            [_intro] call FAC_basePick_startHintLoop;
        };
        case "vote": {
            [] call FAC_basePick_hideWait;
            [] call FAC_basePick_clearMap;
            missionNamespace setVariable ["FAC_basePick_hintLoop", false];
            hintSilent "";
            if (!visibleMap) then { openMap true };
            [] call FAC_basePick_lockMap;
            if (isNull findDisplay 60961) then { createDialog "RscDisplayBasePickVote" };
            [findDisplay 60961] call FAC_basePick_fillVoteList;
        };
        case "done": {
            private _line = if (_choiceList isEqualType "") then { _choiceList } else { "" };
            [_line] call FAC_basePick_showDeploy;
        };
        default { [] call FAC_basePick_closeUi };
    };
};

FAC_basePick_fnc = {
    params ["_action", "_params"];
    if (!hasInterface) exitWith {};
    switch (_action) do {
        case "onLoadWait": {
            private _d = displayNull;
            if (_params isEqualType displayNull) then { _d = _params };
            if (_params isEqualType [] && { count _params > 0 } && { (_params select 0) isEqualType displayNull }) then {
                _d = _params select 0;
            };
            [_d] call FAC_basePick_setWaitText;
        };
        case "onLoadConfirm": {
            private _pos = missionNamespace getVariable ["FAC_basePick_pendingPos", []];
            private _grid = if (count _pos >= 2) then { mapGridPosition _pos } else { "" };
            private _ctrl = (findDisplay 60960) displayCtrl 60971;
            _ctrl ctrlSetText format ["Set the player base at %1?", _grid];
        };
        case "confirmYes": {
            private _pos = missionNamespace getVariable ["FAC_basePick_pendingPos", []];
            private _d = findDisplay 60960;
            if (!isNull _d) then { _d closeDisplay 1 };
            if (count _pos >= 2) then {
                [player, _pos] remoteExec ["FADE_basePick_adminConfirm", 2];
            };
        };
        case "confirmNo": {
            private _d = findDisplay 60960;
            if (!isNull _d) then { _d closeDisplay 1 };
        };
        case "onLoadVote": {
            private _d = displayNull;
            if (_params isEqualType displayNull) then { _d = _params };
            if (_params isEqualType [] && { count _params > 0 } && { (_params select 0) isEqualType displayNull }) then {
                _d = _params select 0;
            };
            [_d] call FAC_basePick_fillVoteList;
            [] spawn {
                sleep 0.05;
                private _disp = findDisplay 60961;
                [_disp] call FAC_basePick_fillVoteList;
                while { !isNull _disp } do {
                    private _left = ceil ((missionNamespace getVariable ["FADE_basePick_deadline", serverTime]) - serverTime);
                    if (_left < 0) then { _left = 0 };
                    private _ctrl = _disp displayCtrl 60981;
                    if (!isNull _ctrl) then { _ctrl ctrlSetText format ["%1 s left.", _left] };
                    sleep 1;
                    _disp = findDisplay 60961;
                };
            };
        };
        case "vote": {
            private _list = (findDisplay 60961) displayCtrl 60980;
            private _sel = lbCurSel _list;
            if (_sel < 0) exitWith { systemChat "Select a choice first."; };
            private _uid = _list lbData _sel;
            [player, _uid] remoteExec ["FADE_basePick_vote", 2];
            systemChat "Vote recorded.";
        };
    };
};

FAC_basePick_clientStart = {
    if (!hasInterface) exitWith {};
    if (worldName == "Altis") exitWith {};
    if (missionNamespace getVariable ["FAC_basePick_clientStarted", false]) exitWith {};
    missionNamespace setVariable ["FAC_basePick_clientStarted", true];
    "FADE_basePickPhase" addPublicVariableEventHandler {
        params ["", "_phase"];
        [_phase] call FAC_basePick_applyPhase;
    };
    "FADE_basePick_choiceList" addPublicVariableEventHandler {
        if (!isNull findDisplay 60961) then { [] call FAC_basePick_fillVoteList };
    };
    [] spawn {
        private _phase = missionNamespace getVariable ["FADE_basePickPhase", ""];
        private _defined = missionNamespace getVariable ["FADE_baseDefined", false];
        if (!_defined && { _phase == "" || { _phase == "waiting" } }) then {
            [] call FAC_basePick_showWait;
        };
        waitUntil { sleep 0.2; !isNull player };
        _phase = missionNamespace getVariable ["FADE_basePickPhase", ""];
        if (_phase != "" && { _phase != "waiting" }) then {
            [_phase] call FAC_basePick_applyPhase;
        } else {
            if (_phase == "waiting") then { [] call FAC_basePick_showWait };
        };
    };
};

missionNamespace setVariable ["FAC_basePick_fnc", FAC_basePick_fnc];
missionNamespace setVariable ["FAC_basePick_applyPhase", FAC_basePick_applyPhase];
missionNamespace setVariable ["FAC_basePick_clientStart", FAC_basePick_clientStart];
