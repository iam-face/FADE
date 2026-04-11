// =============================================================================
// TeleportGui.sqf - Fast Travel GUI (opened from teleportBoard_1..9 or Ctrl+Shift+apostrophe hotkey in initPlayerLocal)
// =============================================================================
// Player picks a destination button (two-click confirm) and is teleported (client-side setPos).
// Destinations are Eden object names or MARKER_<markerName>; player is placed 5 m behind the anchor, facing it.
// Destination tiles (idc 60620+) fill the main panel grid. Shared blur helpers use FAC_teleport_* prefix.
// =============================================================================

// Return-to-base / default Fast Travel anchor (Eden object name)
FAC_teleportGui_destBaseKey = "teleportBase";
FAC_teleportGui_destBtnIdcFirst = 60620;
FAC_teleportGui_destBtnIdcLast = 60639;
FAC_teleportGui_destBtnTextNormal = [1, 1, 1, 1];
FAC_teleportGui_destBtnTextConfirm = [1, 0.2, 0.2, 1];

FAC_teleportGui_fnc_destroyDestButtons = {
    params ["_display"];
    if (isNull _display) exitWith {};
    {
        _x params ["_idc"];
        private _c = _display displayCtrl _idc;
        if (!isNull _c) then { ctrlDelete _c; };
    } forEach (uiNamespace getVariable ["FAC_teleportGui_destButtonMeta", []]);
    uiNamespace setVariable ["FAC_teleportGui_destButtonMeta", []];
};

FAC_teleportGui_fnc_resetDestButtonVisuals = {
    private _display = findDisplay 60600;
    if (isNull _display) exitWith {};
    private _defBg = [0.2, 0.4, 0.62, 1];
    {
        _x params ["_idc", "_objNameMeta", "_label"];
        private _c = _display displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetText _label;
            _c ctrlSetBackgroundColor _defBg;
            _c ctrlSetForegroundColor FAC_teleportGui_destBtnTextNormal;
        };
    } forEach (uiNamespace getVariable ["FAC_teleportGui_destButtonMeta", []]);
};

// Returns [ok, atlPos, faceDir] for teleport offset math (Eden object or MARKER_name).
// Z must be ATL (height above local terrain) for setPosATL — never use getTerrainHeightASL as Z (that is ASL).
FAC_teleportGui_fnc_resolveDestination = {
    params ["_objName"];
    if (_objName find "MARKER_" == 0) then {
        private _mn = _objName select [8];
        if ((markerType _mn) == "") exitWith { [false, [0, 0, 0], 0] };
        private _p = getMarkerPos _mn;
        [true, [_p select 0, _p select 1, 0.15], markerDir _mn]
    } else {
        private _o = missionNamespace getVariable [_objName, objNull];
        if (isNull _o) exitWith { [false, [0, 0, 0], 0] };
        [true, getPosATL _o, getDir _o]
    };
};

// Run inside spawn: blur -> _args call _moveCode -> unblur.
// Pass numeric/array data in _args - do not capture caller private vars inside _moveCode; spawn runs after the
// caller returns, so closures over private locals become undefined (see RPT: Undefined variable _tpPos).
FAC_teleport_fnc_applyBlurAndMove = {
    params ["_moveCode", "_args"];
    if (!(_moveCode isEqualType {})) exitWith {};
    if (isNil "_args") then { _args = [] };
    [_moveCode, _args] spawn {
        params ["_moveCode", "_args"];
        private _blur = ppEffectCreate ["DynamicBlur", 315];
        if (_blur >= 0) then {
            _blur ppEffectEnable true;
            _blur ppEffectAdjust [22];
            _blur ppEffectCommit 0.1;
        };
        private _chroma = ppEffectCreate ["ChromAberration", 316];
        private _chromaOk = _chroma >= 0;
        if (_chromaOk) then {
            _chroma ppEffectEnable true;
            _chroma ppEffectAdjust [0.05, 0.05, true];
            _chroma ppEffectCommit 0.1;
        };
        sleep 0.85;
        _args call _moveCode;
        if (_blur >= 0) then {
            _blur ppEffectAdjust [0];
            _blur ppEffectCommit 0.35;
        };
        if (_chromaOk) then {
            _chroma ppEffectAdjust [0, 0, true];
            _chroma ppEffectCommit 0.35;
        };
        sleep 0.85;
        if (_chromaOk) then { ppEffectDestroy _chroma; };
        if (_blur >= 0) then { ppEffectDestroy _blur; };
    };
};

// Map teleport: rsc\TeleportMapPick.sqf (execVM from teleport boards) - onMapSingleClick must be set from
// a normal script; see PMC wiki debug-teleport pattern. Do not re-add map logic here via call compile.

FAC_teleport_fnc_addReturnToBase = {
    private _aidPrev = player getVariable ["FAC_teleport_returnAid", -1];
    if (_aidPrev >= 0) then { player removeAction _aidPrev };
    private _aid = player addAction [
        "<t color='#00FFFF'>Teleport Back to Base</t>",
        { [] call FAC_teleport_fnc_returnToBase },
        [],
        6,
        false,
        true,
        "",
        "",
        3
    ];
    player setVariable ["FAC_teleport_returnAid", _aid];
    [_aid] spawn {
        params ["_aid"];
        sleep 10;
        if ((player getVariable ["FAC_teleport_returnAid", -1]) isEqualTo _aid) then {
            player removeAction _aid;
            player setVariable ["FAC_teleport_returnAid", -1];
        };
    };
};

FAC_teleport_fnc_returnToBase = {
    private _resolved = [FAC_teleportGui_destBaseKey] call FAC_teleportGui_fnc_resolveDestination;
    _resolved params ["_ok", "_pos", "_dir"];
    if (!_ok) exitWith { systemChat "CTB HQ (teleportBase) not found."; };
    private _dx = sin _dir * 5;
    private _dy = cos _dir * 5;
    private _tpPos = [(_pos select 0) - _dx, (_pos select 1) - _dy, _pos select 2];
    private _faceDir = _tpPos getDir _pos;
    private _doBaseMove = {
        params ["_atl", "_dir"];
        player setPosATL _atl;
        player setDir _dir;
    };
    [_doBaseMove, [_tpPos, _faceDir]] call FAC_teleport_fnc_applyBlurAndMove;
    private _aid = player getVariable ["FAC_teleport_returnAid", -1];
    if (_aid >= 0) then {
        player removeAction _aid;
        player setVariable ["FAC_teleport_returnAid", -1];
    };
    systemChat "Returned to CTB HQ.";
};

FAC_teleportGui_destinations = [
    ["Cargo Slingload", "teleportSlingload"],
    ["Sultan's CQB Killhouse", "teleportCQB"],
    ["Joon's Fires Range", "teleportFires"],
    ["CTB HQ", "teleportBase"],
    ["Juko's Locker Room", "teleportLockerRoom"],
    ["Bean's Medical Area", "teleportMedical"],
    ["Officer Area", "teleportOfficer"],
    ["Pads 1 and 2", "teleportPad1"],
    ["Pads 3, 4 and 5", "teleportPad3"],
    ["Firing Range", "teleportRange"],
    ["Sniper Range", "teleportSniper"],
    ["SDE's Pub", "teleportSDE"],
    ["CTB Specialist Area", "teleportSpecialist"]
];

FAC_teleportGui_fnc_buildPlayerDestinations = {
    private _entries = [];
    private _groups = [];
    private _groupKeys = [];

    {
        if (!isNull _x && { alive _x }) then {
            private _uid = getPlayerUID _x;
            if (_uid != "") then {
                private _grp = group _x;
                private _gKey = str _grp;
                private _idx = _groupKeys find _gKey;
                if (_idx < 0) then {
                    _groupKeys pushBack _gKey;
                    _groups pushBack [_grp, []];
                    _idx = (count _groups) - 1;
                };
                ((_groups select _idx) select 1) pushBack _x;
            };
        };
    } forEach allPlayers;

    // Group blocks sorted by leader name. Inside each block: leader first, then members indented.
    private _groupBlocks = [];
    {
        _x params ["_grp", "_members"];
        if (_members isEqualTo []) then { continue };
        private _leaderObj = leader _grp;
        if (isNull _leaderObj || {!(_leaderObj in _members)}) then {
            _leaderObj = _members select 0;
        };
        private _leaderName = name _leaderObj;
        if (_leaderName == "") then { _leaderName = "Unknown"; };
        private _membersSorted = +_members;
        _membersSorted sort true;
        _groupBlocks pushBack [_leaderName, _leaderObj, _membersSorted];
    } forEach _groups;
    _groupBlocks sort true;

    {
        _x params ["_leaderName", "_leaderObj", "_membersSorted"];
        private _ordered = [];
        _ordered pushBack _leaderObj;
        {
            if (_x != _leaderObj) then { _ordered pushBack _x };
        } forEach _membersSorted;

        {
            private _p = _x;
            private _uid = getPlayerUID _p;
            if (_uid == "") then { continue };
            private _isLeader = _p == _leaderObj;
            private _sameGroup = group _p == group player;
            private _combat = behaviour _p in ["COMBAT", "STEALTH"];
            private _grid = mapGridPosition _p;
            private _groupName = groupId (group _p);
            if (_groupName == "") then { _groupName = "No Group ID"; };
            private _name = name _p;
            if (_name == "") then { _name = "Unknown"; };
            private _label = format [
                "%1%2%3",
                if (_isLeader) then { "" } else { "- " },
                _name,
                if (_p == player) then { " (you)" } else { "" }
            ];
            private _meta = [
                if (_combat) then { "combat" } else { "clear" },
                if (_isLeader) then { "SL" } else { "-" },
                if (_sameGroup) then { "same group" } else { _groupName },
                _grid
            ];
            _entries pushBack [_label, "PLAYER:" + _uid, _meta];
        } forEach _ordered;
    } forEach _groupBlocks;

    _entries
};

FAC_teleportGui_fnc_findPlayerByUid = {
    params ["_uid"];
    private _target = objNull;
    {
        if (!isNull _x && { alive _x } && { getPlayerUID _x == _uid }) exitWith { _target = _x };
    } forEach allPlayers;
    _target
};

FAC_teleportGui_fnc_updatePlayerPreview = {
    params ["_display", "_uid"];
    private _title = _display displayCtrl 60614;
    private _details = _display displayCtrl 60615;
    if (isNull _title || { isNull _details }) exitWith {};
    private _target = [_uid] call FAC_teleportGui_fnc_findPlayerByUid;
    if (isNull _target) exitWith {
        _title ctrlSetStructuredText parseText "<t align='center' color='#FFAAAA' size='1.05'>Player unavailable</t>";
        _details ctrlSetStructuredText parseText "<t color='#BBBBBB'>Select another active player.</t>";
    };
    private _isLeader = leader group _target == _target;
    private _sameGroup = group _target == group player;
    private _combat = behaviour _target in ["COMBAT", "STEALTH"];
    private _groupName = groupId (group _target);
    if (_groupName == "") then { _groupName = "No Group ID"; };
    _title ctrlSetStructuredText parseText format ["<t align='center' color='#FFFFFF' size='1.1'>%1</t>", name _target];
    _details ctrlSetStructuredText parseText format [
        "<t color='#E8E8E8'>Status:</t> <t color='#B0D0FF'>%1</t><br/>" +
        "<t color='#E8E8E8'>SL:</t> <t color='#B0D0FF'>%2</t><br/>" +
        "<t color='#E8E8E8'>Group:</t> <t color='#B0D0FF'>%3</t><br/>" +
        "<t color='#E8E8E8'>Grid:</t> <t color='#B0D0FF'>%4</t><br/>" +
        "<t color='#E8E8E8'>Distance:</t> <t color='#B0D0FF'>%5 m</t>",
        if (_combat) then { "combat" } else { "clear" },
        if (_isLeader) then { "Yes" } else { "No" },
        if (_sameGroup) then { "same group" } else { _groupName },
        mapGridPosition _target,
        round (player distance _target)
    ];
};

FAC_teleportGui_fnc = {
    params ["_action", "_params"];
    private _displayMain = findDisplay 60600;
    private _displayPlayers = findDisplay 60610;
    if (isNull _displayMain && { isNull _displayPlayers } && { !(_action in ["open", "openPlayers"]) }) exitWith {};

    switch _action do {
        case "open": {
            private _defaultObjName = if (_params isEqualType [] && { (count _params) > 0 }) then { _params select 0 } else { "" };
            missionNamespace setVariable ["FAC_teleportGui_defaultDest", _defaultObjName];
            if (!createDialog "RscDisplayTeleport") then {
                systemChat "TELEPORT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "headerRefresh": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            ["onLoad", []] call FAC_teleportGui_fnc;
        };
        case "headerRefreshPlayers": {
            private _display = findDisplay 60610;
            if (isNull _display) exitWith {};
            ["onLoadPlayers", []] call FAC_teleportGui_fnc;
        };
        case "onLoad": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_teleportGui_fnc", FAC_teleportGui_fnc];
            uinamespace setVariable ["FAC_teleportGui_fnc", FAC_teleportGui_fnc];

            missionNamespace setVariable ["FAC_teleportGui_pendingObj", ""];
            [_display] call FAC_teleportGui_fnc_destroyDestButtons;
            private _defaultObjName = missionNamespace getVariable ["FAC_teleportGui_defaultDest", ""];

            private _sorted = +FAC_teleportGui_destinations;
            _sorted sort true;
            private _count = count _sorted;
            if (_count > (FAC_teleportGui_destBtnIdcLast - FAC_teleportGui_destBtnIdcFirst + 1)) then {
                diag_log "[FAC] Teleport GUI: destination count exceeds button idc range.";
            };

            private _meta = [];
            private _idc = FAC_teleportGui_destBtnIdcFirst;
            private _gx0 = 0.04;
            private _gx1 = 0.96;
            private _gy0 = 0.122;
            private _gy1 = 0.772;
            private _gapH = 0.01;
            private _gapV = 0.01;
            private _totalW = _gx1 - _gx0;
            private _totalH = _gy1 - _gy0;
            private _cols = ((ceil (sqrt _count)) max 1) min 5;
            if (_count > 16) then { _cols = 5; };
            private _rows = ceil (_count / _cols);
            private _cellW = (_totalW - _gapH * (_cols - 1)) / _cols;
            private _cellH = (_totalH - _gapV * (_rows - 1)) / _rows;
            private _gi = 0;
            {
                if (_idc > FAC_teleportGui_destBtnIdcLast) exitWith {};
                _x params ["_label", "_objName"];
                private _row = floor (_gi / _cols);
                private _col = _gi % _cols;
                private _xPos = _gx0 + _col * (_cellW + _gapH);
                private _yPos = _gy0 + _row * (_cellH + _gapV);
                private _ctrl = _display ctrlCreate ["RscButton", _idc];
                _ctrl ctrlSetPosition [_xPos, _yPos, _cellW, _cellH];
                _ctrl ctrlCommit 0;
                _ctrl ctrlSetText _label;
                _ctrl ctrlSetBackgroundColor [0.2, 0.4, 0.62, 1];
                _ctrl ctrlSetForegroundColor FAC_teleportGui_destBtnTextNormal;
                private _act = format [
                    "['destBtn', ['%1']] call (missionNamespace getVariable ['FAC_teleportGui_fnc', {}]);",
                    _objName
                ];
                _ctrl buttonSetAction _act;
                _meta pushBack [_idc, _objName, _label];
                _idc = _idc + 1;
                _gi = _gi + 1;
            } forEach _sorted;
            uiNamespace setVariable ["FAC_teleportGui_destButtonMeta", _meta];
            if (_defaultObjName != "") then {
                {
                    _x params ["_idc", "_ob", "_lab"];
                    if (_ob isEqualTo _defaultObjName) exitWith {
                        private _hc = _display displayCtrl _idc;
                        if (!isNull _hc) then { _hc ctrlSetBackgroundColor [0.28, 0.52, 0.78, 1]; };
                    };
                } forEach _meta;
            };
            missionNamespace setVariable ["FAC_teleportGui_defaultDest", ""];
        };
        case "destBtn": {
            _params params ["_objName"];
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            private _pending = missionNamespace getVariable ["FAC_teleportGui_pendingObj", ""];
            if (_objName isEqualTo _pending) then {
                missionNamespace setVariable ["FAC_teleportGui_pendingObj", ""];
                [] call FAC_teleportGui_fnc_resetDestButtonVisuals;

                private _resolved = [_objName] call FAC_teleportGui_fnc_resolveDestination;
                _resolved params ["_ok", "_pos", "_dir"];
                if (!_ok) exitWith {
                    systemChat format ["Destination not found: %1", _objName];
                };
                private _dx = sin _dir * 5;
                private _dy = cos _dir * 5;
                private _tpPos = [(_pos select 0) - _dx, (_pos select 1) - _dy, _pos select 2];
                private _faceDir = _tpPos getDir _pos;
                private _doGuiMove = {
                    params ["_atl", "_dir"];
                    player setPosATL _atl;
                    player setDir _dir;
                };
                closeDialog 0;
                [_doGuiMove, [_tpPos, _faceDir]] call FAC_teleport_fnc_applyBlurAndMove;
                systemChat "Fast travel complete.";
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            } else {
                missionNamespace setVariable ["FAC_teleportGui_pendingObj", _objName];
                [] call FAC_teleportGui_fnc_resetDestButtonVisuals;
                {
                    _x params ["_idc", "_ob", "_lab"];
                    if (_ob isEqualTo _objName) exitWith {
                        private _c = _display displayCtrl _idc;
                        if (!isNull _c) then {
                            _c ctrlSetText "Are you sure?";
                            _c ctrlSetForegroundColor FAC_teleportGui_destBtnTextConfirm;
                            _c ctrlSetBackgroundColor [0.22, 0.1, 0.1, 1];
                        };
                    };
                } forEach (uiNamespace getVariable ["FAC_teleportGui_destButtonMeta", []]);
            };
        };
        case "openPlayers": {
            if (!(call FAC_playerCanTeleportToPlayers)) exitWith {
                systemChat "Teleport to player is SL-only (admin/Zeus override).";
            };
            if (!isNull (findDisplay 60600)) then { closeDialog 0; };
            if (!createDialog "RscDisplayTeleportPlayers") then {
                systemChat "TELEPORT PLAYERS GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoadPlayers": {
            private _display = findDisplay 60610;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60611;
            lbClear _list;
            private _entries = call FAC_teleportGui_fnc_buildPlayerDestinations;
            {
                _x params ["_name", "_key"];
                private _idx = _list lbAdd _name;
                _list lbSetData [_idx, _key];
            } forEach _entries;
            if (lbSize _list > 0) then {
                _list lbSetCurSel 0;
                ["selChangedPlayers", []] call FAC_teleportGui_fnc;
            } else {
                private _title = _display displayCtrl 60614;
                private _details = _display displayCtrl 60615;
                if (!isNull _title) then { _title ctrlSetStructuredText parseText "<t align='center' color='#FFAAAA'>No active players</t>"; };
                if (!isNull _details) then { _details ctrlSetStructuredText parseText "<t color='#BBBBBB'>No connected players found.</t>"; };
            };
        };
        case "selChangedPlayers": {
            private _display = findDisplay 60610;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60611;
            private _cur = lbCurSel _list;
            if (_cur < 0) exitWith {};
            private _key = _list lbData _cur;
            if (_key find "PLAYER:" != 0) exitWith {};
            private _uid = _key select [7];
            [_display, _uid] call FAC_teleportGui_fnc_updatePlayerPreview;
        };
        case "backToMain": {
            if (!isNull (findDisplay 60610)) then { closeDialog 0; };
            ["open", [FAC_teleportGui_destBaseKey]] call FAC_teleportGui_fnc;
        };
        case "teleportPlayer": {
            if (!(call FAC_playerCanTeleportToPlayers)) exitWith {
                systemChat "Teleport to player is SL-only (admin/Zeus override).";
            };
            private _display = findDisplay 60610;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60611;
            private _cur = lbCurSel _list;
            if (_cur < 0) exitWith { systemChat "Select a player."; };
            private _key = _list lbData _cur;
            if (_key find "PLAYER:" != 0) exitWith { systemChat "Invalid player entry."; };
            private _uid = _key select [7];
            private _targetPlayer = [_uid] call FAC_teleportGui_fnc_findPlayerByUid;
            if (isNull _targetPlayer) exitWith { systemChat "Selected player is unavailable."; };
            if (_targetPlayer == player) exitWith { systemChat "You are already at your position."; };
            private _tgtVeh = vehicle _targetPlayer;
            if (_tgtVeh != _targetPlayer) then {
                if ((_tgtVeh emptyPositions "cargo") < 1) exitWith {
                    systemChat format [
                        "Cannot redeploy to %1: their vehicle has no free cargo seats.",
                        name _targetPlayer
                    ];
                };
            };
            private _doPlayerMove = {
                params ["_uid"];
                private _t = [_uid] call FAC_teleportGui_fnc_findPlayerByUid;
                if (isNull _t) exitWith { systemChat "Teleport cancelled: player unavailable."; };
                private _v = vehicle _t;
                if (_v == _t) then {
                    private _anchorPos = getPosATL _t;
                    private _anchorDir = getDir _t;
                    private _dx = sin _anchorDir * 5;
                    private _dy = cos _anchorDir * 5;
                    private _tpPos = [(_anchorPos select 0) - _dx, (_anchorPos select 1) - _dy, _anchorPos select 2];
                    private _faceDir = _tpPos getDir _anchorPos;
                    player setPosATL _tpPos;
                    player setDir _faceDir;
                } else {
                    if ((_v emptyPositions "cargo") < 1) exitWith {
                        systemChat format [
                            "Teleport cancelled: %1's vehicle has no free cargo seats.",
                            name _t
                        ];
                    };
                    if (vehicle player != player) then { moveOut player; };
                    player moveInCargo _v;
                };
                systemChat format ["Redeployed to %1.", name _t];
            };
            closeDialog 0;
            [_doPlayerMove, [_uid]] call FAC_teleport_fnc_applyBlurAndMove;
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};

missionNamespace setVariable ["FAC_teleportGui_fnc", FAC_teleportGui_fnc];
