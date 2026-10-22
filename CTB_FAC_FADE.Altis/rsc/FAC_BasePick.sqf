// =============================================================================
// FAC_BasePick.sqf — client map click, confirm dialog, and vote dialog
// Compiled from initPlayerLocal after FADE_clientInitReady.
// =============================================================================

FAC_basePick_posOk = {
    params ["_pos"];
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith { false };
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!(_x isEqualType 0) || { !(_y isEqualType 0) }) exitWith { false };
    if (surfaceIsWater [_x, _y]) exitWith { false };
    private _minX = missionNamespace getVariable ["FADE_mapMinX", 0];
    private _maxX = missionNamespace getVariable ["FADE_mapMaxX", worldSize];
    private _minY = missionNamespace getVariable ["FADE_mapMinY", 0];
    private _maxY = missionNamespace getVariable ["FADE_mapMaxY", worldSize];
    (_x >= _minX) && { _x <= _maxX } && { _y >= _minY } && { _y <= _maxY }
};

FAC_basePick_clearMap = {
    onMapSingleClick (str false);
};

FAC_basePick_closeUi = {
    if (!hasInterface) exitWith {};
    [] call FAC_basePick_clearMap;
    hintSilent "";
    private _confirm = findDisplay 60960;
    if (!isNull _confirm) then { _confirm closeDisplay 1 };
    private _vote = findDisplay 60961;
    if (!isNull _vote) then { _vote closeDisplay 1 };
    openMap false;
    missionNamespace setVariable ["FAC_basePick_hintLoop", false];
};

FAC_basePick_armMap = {
    params ["_hintText"];
    if (!hasInterface) exitWith {};
    [] call FAC_basePick_clearMap;
    onMapSingleClick "if (!isNil 'FAC_basePick_onMapClick') then { _pos call FAC_basePick_onMapClick }; true";
    openMap true;
    hint _hintText;
};

FAC_basePick_onMapClick = {
    params ["_pos"];
    if (!hasInterface) exitWith {};
    if (!isNull findDisplay 60960) exitWith {};
    private _phase = missionNamespace getVariable ["FADE_basePickPhase", ""];
    if !([_pos] call FAC_basePick_posOk) exitWith {
        systemChat "That point is off the map or in the water.";
    };
    if (_phase == "admin") exitWith {
        missionNamespace setVariable ["FAC_basePick_pendingPos", _pos];
        createDialog "RscDisplayBasePickConfirm";
    };
    if (_phase == "suggest") exitWith {
        [player, _pos] remoteExec ["FADE_basePick_suggest", 2];
        hint format ["Marked %1.", mapGridPosition _pos];
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
            hint format ["%1%2%3 s left.", _intro, toString [10], _left];
            sleep 1;
        };
    };
};

FAC_basePick_applyPhase = {
    params [["_phase", ""]];
    if (!hasInterface) exitWith {};
    if (isNull player) exitWith {};
    if (_phase == "") then { _phase = missionNamespace getVariable ["FADE_basePickPhase", ""] };
    switch (_phase) do {
        case "admin": {
            [] call FAC_basePick_closeUi;
            if ([] call FAC_basePick_iAmAdmin) then {
                ["Click the map to place the player base."] call FAC_basePick_armMap;
            } else {
                hint "An admin is placing the player base.";
            };
        };
        case "adminLeft": {
            [] call FAC_basePick_closeUi;
            hint "The admin left. Mark a point on the map.";
        };
        case "suggest": {
            private _vote = findDisplay 60961;
            if (!isNull _vote) then { _vote closeDisplay 1 };
            ["Click the map to mark your choice for the player base."] call FAC_basePick_armMap;
            ["Click the map to mark your choice for the player base."] call FAC_basePick_startHintLoop;
        };
        case "vote": {
            [] call FAC_basePick_clearMap;
            missionNamespace setVariable ["FAC_basePick_hintLoop", false];
            hintSilent "";
            openMap true;
            if (isNull findDisplay 60961) then { createDialog "RscDisplayBasePickVote" };
        };
        case "done": {
            [] call FAC_basePick_closeUi;
            if (worldName != "Altis") then {
                private _bp = missionNamespace getVariable ["FADE_basePos", []];
                if (_bp isEqualType [] && { count _bp >= 2 }) then {
                    private _here = getPosATL player;
                    if ((_here distance2D _bp) > 80) then {
                        [_bp, 0] call FADE_clientTeleportPos;
                    };
                };
            };
        };
        default { [] call FAC_basePick_closeUi };
    };
};

FAC_basePick_fnc = {
    params ["_action", "_params"];
    if (!hasInterface) exitWith {};
    switch (_action) do {
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
            private _list = (findDisplay 60961) displayCtrl 60980;
            lbClear _list;
            {
                _x params ["_uid", "_nm", "_px", "_py"];
                private _grid = mapGridPosition [_px, _py];
                private _row = _list lbAdd format ["%1's Choice  %2", _nm, _grid];
                _list lbSetData [_row, _uid];
            } forEach (missionNamespace getVariable ["FADE_basePick_choiceList", []]);
            if ((lbSize _list) > 0) then { _list lbSetCurSel 0 };
            [] spawn {
                while { !isNull findDisplay 60961 } do {
                    private _left = ceil ((missionNamespace getVariable ["FADE_basePick_deadline", serverTime]) - serverTime);
                    if (_left < 0) then { _left = 0 };
                    private _ctrl = (findDisplay 60961) displayCtrl 60981;
                    if (!isNull _ctrl) then { _ctrl ctrlSetText format ["%1 s left.", _left] };
                    sleep 1;
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
    [] spawn {
        waitUntil { sleep 0.2; !isNull player };
        "FADE_basePickPhase" addPublicVariableEventHandler {
            params ["", "_phase"];
            [_phase] call FAC_basePick_applyPhase;
        };
        private _phase = missionNamespace getVariable ["FADE_basePickPhase", ""];
        if (_phase != "" && { _phase != "waiting" }) then {
            [_phase] call FAC_basePick_applyPhase;
        };
    };
};

missionNamespace setVariable ["FAC_basePick_fnc", FAC_basePick_fnc];
missionNamespace setVariable ["FAC_basePick_applyPhase", FAC_basePick_applyPhase];
missionNamespace setVariable ["FAC_basePick_clientStart", FAC_basePick_clientStart];
