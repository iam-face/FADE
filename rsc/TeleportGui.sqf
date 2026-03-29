// =============================================================================
// TeleportGui.sqf - Fast Travel GUI (opened from teleportBoard_1..8)
// =============================================================================
// Player selects a destination and is teleported there (client-side setPos).
// Destinations are Eden object names; player is placed 5 m behind the object, facing it.
// List is sorted A–Z; right panel: 60604 = centered destination title; 60605 = JPG (img\teleport_<EdenName>.jpg)
// (no embedded CT_MAP - caused CTDs). Expected files, matching FAC_teleportGui_destinations Eden names:
//   teleport_BASE_1.jpg, teleport_MEDICAL_1.jpg, teleport_HP_4.jpg, teleport_firingRangeBoard.jpg,
//   teleport_cqbBoard.jpg, teleport_VEH_2.jpg, teleport_teleportBoard_7.jpg
//   teleport_SDE.jpg (teleportBoard_8 via FAC_teleportGui_previewPathOverrides)
// Optional fallback if a specific file is missing: img\teleport_default.jpg
// Shared blur + map teleport helpers use FAC_teleport_* prefix.
// =============================================================================

FAC_teleportGui_previewPathOverrides = createHashMap;
FAC_teleportGui_previewPathOverrides set ["teleportBoard_8", "img\teleport_SDE.jpg"];

FAC_teleportGui_fnc_previewImagePath = {
    params ["_objName"];
    if (_objName in FAC_teleportGui_previewPathOverrides) exitWith {
        FAC_teleportGui_previewPathOverrides get _objName
    };
    format ["img\teleport_%1.jpg", _objName]
};

FAC_teleportGui_fnc_updateDestPreview = {
    params ["_display", "_objName"];
    if (_objName isEqualTo "" || {!(_objName isEqualType "")}) exitWith {};
    private _st = _display displayCtrl 60604;
    private _pic = _display displayCtrl 60605;
    if (isNull _st || {isNull _pic}) exitWith {};
    private _list = _display displayCtrl 60601;
    private _cur = lbCurSel _list;
    private _label = if (_cur >= 0) then { _list lbText _cur } else { "?" };

    private _path = [_objName] call FAC_teleportGui_fnc_previewImagePath;
    private _pathDefault = "img\teleport_default.jpg";
    private _tex = "";
    if (fileExists _path) then {
        _tex = _path;
    } else {
        if (fileExists _pathDefault) then { _tex = _pathDefault };
    };
    _pic ctrlSetText _tex;

    private _obj = missionNamespace getVariable [_objName, objNull];
    if (isNull _obj) exitWith {
        private _hint = if (_tex isEqualTo "") then {
            "<br/><t color='#888888' size='0.85'>Add: " + _path + "</t>"
        } else {
            ""
        };
        _st ctrlSetStructuredText parseText format [
            "<t align='center' valign='middle' size='1.05' color='#FFAAAA'>%1</t><br/><t align='center' color='#AAAAAA' size='0.88'>Eden object not found.</t>%2",
            _label,
            _hint
        ];
    };
    private _title = format ["<t align='center' valign='middle' size='1.15' color='#FFFFFF'>%1</t>", _label];
    if (_tex isEqualTo "") then {
        _title = _title + format ["<br/><t align='center' color='#888888' size='0.78'>Add image: %1</t>", _path];
    };
    _st ctrlSetStructuredText parseText _title;
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
        private _pp = ppEffectCreate ["DynamicBlur", 315];
        _pp ppEffectEnable true;
        _pp ppEffectAdjust [0.55];
        _pp ppEffectCommit 0.12;
        sleep 1;
        _args call _moveCode;
        _pp ppEffectAdjust [0];
        _pp ppEffectCommit 0.22;
        sleep 1;
        ppEffectDestroy _pp;
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
    private _base = missionNamespace getVariable ["BASE_1", objNull];
    if (isNull _base) exitWith { systemChat "Base (BASE_1) not found."; };
    private _pos = getPosATL _base;
    private _dir = getDir _base;
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
    systemChat "Returned to base.";
};

FAC_teleportGui_destinations = [
    ["Base", "BASE_1"],
    ["Medical Area", "MEDICAL_1"],
    ["Pads 3, 4 and 5", "HP_4"],
    ["Firing Range", "firingRangeBoard"],
    ["CQB Killhouse", "cqbBoard"],
    ["Vehicle Pad 2", "VEH_2"],
    ["CTB Locker Room", "teleportBoard_7"],
    ["SDE's Pub", "teleportBoard_8"]
];

FAC_teleportGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60600;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            private _defaultObjName = if (_params isEqualType [] && { (count _params) > 0 }) then { _params select 0 } else { "" };
            missionNamespace setVariable ["FAC_teleportGui_defaultDest", _defaultObjName];
            if (!createDialog "RscDisplayTeleport") then {
                systemChat "TELEPORT GUI: RESOURCE NOT FOUND.";
            };
        };
        case "selChanged": {
            if (missionNamespace getVariable ["FAC_teleportGui_suppressPreviewSel", false]) exitWith {};
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60601;
            private _cur = lbCurSel _list;
            if (_cur < 0) exitWith {};
            private _objName = _list lbData _cur;
            [_display, _objName] call FAC_teleportGui_fnc_updateDestPreview;
        };
        case "onLoad": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_teleportGui_fnc", FAC_teleportGui_fnc];

            private _list = _display displayCtrl 60601;
            lbClear _list;
            private _sorted = +FAC_teleportGui_destinations;
            _sorted sort true;
            {
                _x params ["_name", "_objName"];
                private _idx = _list lbAdd _name;
                _list lbSetData [_idx, _objName];
            } forEach _sorted;
            if (lbSize _list > 0) then {
                private _defaultObjName = missionNamespace getVariable ["FAC_teleportGui_defaultDest", ""];
                private _sel = 0;
                if (_defaultObjName != "") then {
                    for "_i" from 0 to (lbSize _list - 1) do {
                        if ((_list lbData _i) == _defaultObjName) exitWith { _sel = _i };
                    };
                } else {
                    for "_i" from 0 to (lbSize _list - 1) do {
                        if ((_list lbData _i) == "BASE_1") exitWith { _sel = _i };
                    };
                };
                missionNamespace setVariable ["FAC_teleportGui_suppressPreviewSel", true];
                _list lbSetCurSel _sel;
                missionNamespace setVariable ["FAC_teleportGui_suppressPreviewSel", false];
                [_display, _list lbData _sel] call FAC_teleportGui_fnc_updateDestPreview;
            };
            missionNamespace setVariable ["FAC_teleportGui_defaultDest", ""];
        };
        case "teleport": {
            private _display = findDisplay 60600;
            if (isNull _display) exitWith {};
            private _list = _display displayCtrl 60601;
            private _cur = lbCurSel _list;
            if (_cur < 0) exitWith { systemChat "Select a destination."; };
            private _objName = _list lbData _cur;
            if (_objName == "") exitWith { systemChat "Invalid destination."; };

            private _obj = missionNamespace getVariable [_objName, objNull];
            if (isNull _obj) then {
                systemChat format ["Destination not found: %1", _objName];
            } else {
                private _pos = getPosATL _obj;
                private _dir = getDir _obj;
                private _dx = sin _dir * 5;
                private _dy = cos _dir * 5;
                private _tpPos = [(_pos select 0) - _dx, (_pos select 1) - _dy, _pos select 2];
                private _faceDir = _tpPos getDir _pos;
                private _doGuiMove = {
                    params ["_atl", "_dir"];
                    player setPosATL _atl;
                    player setDir _dir;
                };
                [_doGuiMove, [_tpPos, _faceDir]] call FAC_teleport_fnc_applyBlurAndMove;
                closeDialog 0;
                systemChat "Fast travel complete.";
            };
        };
    };
};
