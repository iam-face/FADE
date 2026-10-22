// BuildGui.sqf - catalog dialog and local placement camera.
// The camera and the preview are local. The server creates the real object.
// A simple object has no PhysX body, but its Geometry LOD is still a solid shape.
// A placed piece hits that shape. setPhysicsCollisionFlag false drops PhysX and geometry collision.
// Roadway stays. The command is local, and the preview is local.
// The command string stays compiled because the SQF-VM command list predates Arma 2.18.
// https://community.bistudio.com/wiki/createSimpleObject
// https://community.bistudio.com/wiki/setPhysicsCollisionFlag
// Camera movement follows the vehicle placement camera.

FAC_build_clearGhostCollision = compile "_this setPhysicsCollisionFlag false";

if (isNil "FADE_build_spotBlocked") then {
    call compile preprocessFileLineNumbers "rsc\BuildCommon.sqf";
};

FAC_buildGui_IDD = 60950;
FAC_buildGui_LIST = 60951;
FAC_buildGui_CAT = 60961;
FAC_buildGui_SUB = 60962;
FAC_buildGui_SEARCH = 60963;

FAC_build_placeStatus = {
    params ["_clear"];
    private _state = if (_clear) then { "Clear" } else { "Blocked" };
    titleText [
        format [
            "%1. WASD moves the camera. Mouse looks. Wheel sets distance. Q and E turn the piece. Page Up raises it. Page Down lowers it. T follows the slope. Space places. Esc returns to the menu. Ctrl+Z undoes the last piece you placed.",
            _state
        ],
        "PLAIN DOWN",
        0.3
    ];
    titleFadeOut 9999;
};

// Fixed distance in front of the camera yaw, then straight down onto the surface. Pitch is ignored.
FAC_build_ghostAsl = {
    params ["_ghost"];
    private _dist = missionNamespace getVariable ["FAC_build_camDist", 6];
    private _yaw = missionNamespace getVariable ["FAC_build_camYaw", 0];
    private _camAgl = ASLToAGL (missionNamespace getVariable ["FAC_build_camPos", [0, 0, 0]]);
    private _x = (_camAgl select 0) + ((sin _yaw) * _dist);
    private _y = (_camAgl select 1) + ((cos _yaw) * _dist);
    private _top = AGLToASL [_x, _y, 40];
    private _bot = AGLToASL [_x, _y, -5];
    private _hits = lineIntersectsSurfaces [_top, _bot, _ghost, player, true, 1, "GEOM", "NONE"];
    private _asl = if (count _hits > 0) then {
        (_hits select 0) select 0
    } else {
        AGLToASL [_x, _y, 0]
    };
    private _raise = missionNamespace getVariable ["FAC_build_height", 0];
    [_asl select 0, _asl select 1, (_asl select 2) + _raise]
};

FAC_build_placeTeardown = {
    missionNamespace setVariable ["FAC_build_active", false];
    private _frame = missionNamespace getVariable ["FAC_build_frameEh", -1];
    if (_frame >= 0) then { removeMissionEventHandler ["EachFrame", _frame] };
    missionNamespace setVariable ["FAC_build_frameEh", -1];
    private _disp = findDisplay 46;
    if (!isNull _disp) then {
        {
            _x params ["_type", "_id"];
            _disp displayRemoveEventHandler [_type, _id];
        } forEach (missionNamespace getVariable ["FAC_build_dispEh", []]);
    };
    missionNamespace setVariable ["FAC_build_dispEh", []];
    private _cam = missionNamespace getVariable ["FAC_build_cam", objNull];
    if (!isNull _cam) then {
        _cam cameraEffect ["Terminate", "BACK"];
        camDestroy _cam;
    };
    missionNamespace setVariable ["FAC_build_cam", objNull];
    showCinemaBorder true;
    private _ghost = missionNamespace getVariable ["FAC_build_ghostObj", objNull];
    if (!isNull _ghost) then { deleteVehicle _ghost };
    missionNamespace setVariable ["FAC_build_ghostObj", objNull];
    missionNamespace setVariable ["FAC_build_class", ""];
    titleText ["", "PLAIN"];
    titleFadeOut 0;
};

FAC_build_ghostStop = {
    missionNamespace setVariable ["FAC_build_cancel", true];
    if !(missionNamespace getVariable ["FAC_build_spawnLive", false]) then {
        [] call FAC_build_placeTeardown;
    };
};

FAC_build_onFrame = {
    if !(missionNamespace getVariable ["FAC_build_active", false]) exitWith {};
    private _cam = missionNamespace getVariable ["FAC_build_cam", objNull];
    private _ghost = missionNamespace getVariable ["FAC_build_ghostObj", objNull];
    if (isNull _cam || { isNull _ghost }) exitWith {};

    private _now = time;
    private _dt = _now - (missionNamespace getVariable ["FAC_build_tick", _now]);
    missionNamespace setVariable ["FAC_build_tick", _now];
    if (_dt < 0) then { _dt = 0 };
    if (_dt > 0.1) then { _dt = 0.1 };

    private _held = missionNamespace getVariable ["FAC_build_held", []];
    private _shift = (42 in _held) || { 54 in _held };
    private _speed = if (_shift) then { 24 } else { 8 };
    private _camYaw = missionNamespace getVariable ["FAC_build_camYaw", 0];
    private _pitch = missionNamespace getVariable ["FAC_build_pitch", -20];
    private _look = [
        (sin _camYaw) * (cos _pitch),
        (cos _camYaw) * (cos _pitch),
        sin _pitch
    ];
    private _right = _look vectorCrossProduct [0, 0, 1];
    if ((vectorMagnitude _right) < 0.05) then { _right = [1, 0, 0] };
    _right = vectorNormalized _right;
    private _step = [0, 0, 0];
    if (17 in _held) then { _step = _step vectorAdd _look };
    if (31 in _held) then { _step = _step vectorAdd (_look vectorMultiply -1) };
    if (32 in _held) then { _step = _step vectorAdd _right };
    if (30 in _held) then { _step = _step vectorAdd (_right vectorMultiply -1) };
    private _camPos = missionNamespace getVariable ["FAC_build_camPos", eyePos player];
    if ((vectorMagnitude _step) > 0) then {
        _camPos = _camPos vectorAdd ((vectorNormalized _step) vectorMultiply (_speed * _dt));
    };
    private _agl = ASLToAGL _camPos;
    if !([] call FADE_build_anywhere) then {
        private _base = missionNamespace getVariable ["FADE_basePos", []];
        private _radius = missionNamespace getVariable ["FADE_buildRadius", 500];
        if (count _base >= 2) then {
            private _dx = (_agl select 0) - (_base select 0);
            private _dy = (_agl select 1) - (_base select 1);
            private _dist = sqrt ((_dx * _dx) + (_dy * _dy));
            if (_dist > _radius && { _dist > 0 }) then {
                private _s = _radius / _dist;
                _agl = [(_base select 0) + (_dx * _s), (_base select 1) + (_dy * _s), _agl select 2];
            };
        };
    };
    _agl set [2, ((_agl select 2) max 0.8) min 40];
    _camPos = AGLToASL _agl;
    missionNamespace setVariable ["FAC_build_camPos", _camPos];
    _cam setPosASL _camPos;
    _cam setVectorDirAndUp [_look, [0, 0, 1]];

    if (!isNull player) then {
        player setDir (missionNamespace getVariable ["FAC_build_playerDir", getDir player]);
    };

    private _raise = missionNamespace getVariable ["FAC_build_height", 0];
    if (201 in _held) then { _raise = (_raise + (1.5 * _dt)) min 12 };
    if (209 in _held) then { _raise = (_raise - (1.5 * _dt)) max -2 };
    missionNamespace setVariable ["FAC_build_height", _raise];

    private _surface = [_ghost] call FAC_build_ghostAsl;
    if (count _surface >= 3) then {
        private _dir = _camYaw + (missionNamespace getVariable ["FAC_build_yaw", 0]);
        private _up = [0, 0, 1];
        if (missionNamespace getVariable ["FAC_build_align", false]) then {
            private _n = surfaceNormal _surface;
            if (_n isEqualType [] && { count _n == 3 } && { (vectorMagnitude _n) > 0.01 }) then { _up = _n };
        };
        _ghost setPosASL _surface;
        _ghost setVectorDirAndUp [[sin _dir, cos _dir, 0], _up];
    };

    if (_now >= (missionNamespace getVariable ["FAC_build_nextCheck", 0])) then {
        missionNamespace setVariable ["FAC_build_nextCheck", _now + 0.1];
        private _why = [typeOf _ghost, getPosATL _ghost, getDir _ghost, _ghost] call FADE_build_spotBlocked;
        private _clear = _why == "";
        missionNamespace setVariable ["FAC_build_blocked", !_clear];
        private _was = missionNamespace getVariable ["FAC_build_wasClear", true];
        if (_was isEqualTo _clear) exitWith {};
        missionNamespace setVariable ["FAC_build_wasClear", _clear];
        [_clear] call FAC_build_placeStatus;
    };
};

FAC_build_bindInput = {
    private _disp = findDisplay 46;
    if (isNull _disp) exitWith {};
    private _ids = [];
    private _down = _disp displayAddEventHandler ["KeyDown", {
        params ["_d", "_key"];
        if !(missionNamespace getVariable ["FAC_build_active", false]) exitWith { false };
        private _held = missionNamespace getVariable ["FAC_build_held", []];
        private _undo = _key == 44 && { (29 in _held) || { 157 in _held } };
        private _used = _undo || { _key in [1, 16, 17, 18, 20, 29, 30, 31, 32, 42, 54, 57, 157, 201, 209] };
        if (_used) then {
            private _held = missionNamespace getVariable ["FAC_build_held", []];
            private _fresh = !(_key in _held);
            if (_fresh) then {
                _held pushBack _key;
                missionNamespace setVariable ["FAC_build_held", _held];
            };
            if (_undo && { _fresh }) then {
                [player] remoteExec ["FADE_build_undo", 2];
            };
            if (_key == 1) then { missionNamespace setVariable ["FAC_build_cancel", true] };
            if (_key == 57 && { !(missionNamespace getVariable ["FAC_build_spaceDown", false]) }) then {
                missionNamespace setVariable ["FAC_build_spaceDown", true];
                missionNamespace setVariable ["FAC_build_confirm", true];
            };
            if (_key == 16 || { _key == 18 }) then {
                private _yaw = missionNamespace getVariable ["FAC_build_yaw", 0];
                _yaw = _yaw + (if (_key == 16) then { -5 } else { 5 });
                if (_yaw < 0) then { _yaw = _yaw + 360 };
                if (_yaw >= 360) then { _yaw = _yaw - 360 };
                missionNamespace setVariable ["FAC_build_yaw", _yaw];
            };
            if (_key == 20 && { _fresh }) then {
                missionNamespace setVariable ["FAC_build_align", !(missionNamespace getVariable ["FAC_build_align", false])];
            };
        };
        _used
    }];
    _ids pushBack ["KeyDown", _down];
    private _up = _disp displayAddEventHandler ["KeyUp", {
        params ["_d", "_key"];
        private _held = missionNamespace getVariable ["FAC_build_held", []];
        missionNamespace setVariable ["FAC_build_held", _held - [_key]];
        if (_key == 57) then { missionNamespace setVariable ["FAC_build_spaceDown", false] };
        false
    }];
    _ids pushBack ["KeyUp", _up];
    private _move = _disp displayAddEventHandler ["MouseMoving", {
        params ["_d", "_dx", "_dy"];
        if !(missionNamespace getVariable ["FAC_build_active", false]) exitWith { false };
        private _camYaw = missionNamespace getVariable ["FAC_build_camYaw", 0];
        private _pitch = missionNamespace getVariable ["FAC_build_pitch", -20];
        missionNamespace setVariable ["FAC_build_camYaw", _camYaw + (_dx * 0.15)];
        missionNamespace setVariable ["FAC_build_pitch", ((_pitch - (_dy * 0.15)) max -70) min 50];
        true
    }];
    _ids pushBack ["MouseMoving", _move];
    private _wheel = _disp displayAddEventHandler ["MouseZChanged", {
        params ["_d", "_scroll"];
        if !(missionNamespace getVariable ["FAC_build_active", false]) exitWith { false };
        private _dist = missionNamespace getVariable ["FAC_build_camDist", 6];
        _dist = (_dist + (_scroll * 0.4)) max 2 min 25;
        missionNamespace setVariable ["FAC_build_camDist", _dist];
        true
    }];
    _ids pushBack ["MouseZChanged", _wheel];
    private _click = _disp displayAddEventHandler ["MouseButtonDown", {
        params ["_d", "_btn"];
        missionNamespace getVariable ["FAC_build_active", false]
    }];
    _ids pushBack ["MouseButtonDown", _click];
    missionNamespace setVariable ["FAC_build_dispEh", _ids];
    private _frame = addMissionEventHandler ["EachFrame", { [] call FAC_build_onFrame }];
    missionNamespace setVariable ["FAC_build_frameEh", _frame];
};

FAC_build_placeOne = {
    private _ghost = missionNamespace getVariable ["FAC_build_ghostObj", objNull];
    if (isNull _ghost) exitWith { false };
    if (missionNamespace getVariable ["FAC_build_blocked", false]) exitWith {
        systemChat "That spot is blocked.";
        false
    };
    private _class = missionNamespace getVariable ["FAC_build_class", ""];
    if (_class == "") then { _class = typeOf _ghost };
    if (_class == "") exitWith { false };
    private _simple = missionNamespace getVariable ["FAC_build_optSimple", false];
    private _pos = if (_simple) then { getPosASL _ghost } else { getPosATL _ghost };
    [
        player,
        _class,
        _pos,
        getDir _ghost,
        vectorUp _ghost,
        missionNamespace getVariable ["FAC_build_align", false],
        missionNamespace getVariable ["FAC_build_optSim", true],
        missionNamespace getVariable ["FAC_build_optDamage", true],
        _simple,
        missionNamespace getVariable ["FAC_build_lastRole", ""]
    ] remoteExec ["FADE_build_place", 2];
    true
};

FAC_build_ghostStart = {
    params [["_class", ""]];
    if (!hasInterface) exitWith {};
    if (_class == "") exitWith {};
    if (missionNamespace getVariable ["FAC_build_active", false]) exitWith {};
    missionNamespace setVariable ["FAC_build_active", true];
    missionNamespace setVariable ["FAC_build_spawnLive", true];
    [_class] spawn {
        params ["_class"];
        private _fade = 0.35;
        missionNamespace setVariable ["FAC_build_cancel", false];
        missionNamespace setVariable ["FAC_build_confirm", false];
        missionNamespace setVariable ["FAC_build_spaceDown", false];
        missionNamespace setVariable ["FAC_build_held", []];
        missionNamespace setVariable ["FAC_build_height", 0];
        missionNamespace setVariable ["FAC_build_camDist", 6];
        missionNamespace setVariable ["FAC_build_yaw", 0];
        missionNamespace setVariable ["FAC_build_align", false];
        missionNamespace setVariable ["FAC_build_blocked", true];
        missionNamespace setVariable ["FAC_build_wasClear", "unset"];
        missionNamespace setVariable ["FAC_build_nextCheck", 0];
        missionNamespace setVariable ["FAC_build_camYaw", getDir player];
        missionNamespace setVariable ["FAC_build_pitch", -20];
        missionNamespace setVariable ["FAC_build_playerDir", getDir player];
        missionNamespace setVariable ["FAC_build_tick", time];
        missionNamespace setVariable ["FAC_build_camPos", eyePos player];

        cutText ["", "BLACK OUT", _fade];
        sleep (_fade max 0.1);
        if (!isNull (findDisplay 60950)) then { closeDialog 0 };

        private _failed = false;
        private _cam = "camera" camCreate (ASLToAGL (eyePos player));
        missionNamespace setVariable ["FAC_build_cam", _cam];
        if (isNull _cam) then {
            _failed = true;
        } else {
            _cam cameraEffect ["Internal", "BACK"];
            showCinemaBorder false;
            _cam setPosASL (missionNamespace getVariable ["FAC_build_camPos", eyePos player]);
            private _yaw0 = missionNamespace getVariable ["FAC_build_camYaw", 0];
            private _pitch0 = missionNamespace getVariable ["FAC_build_pitch", -20];
            _cam setVectorDirAndUp [[
                (sin _yaw0) * (cos _pitch0),
                (cos _yaw0) * (cos _pitch0),
                sin _pitch0
            ], [0, 0, 1]];
            private _ghost = createSimpleObject [_class, eyePos player, true];
            if (isNull _ghost) then {
                private _model = getText (configFile >> "CfgVehicles" >> _class >> "model");
                if (_model != "") then {
                    _ghost = createSimpleObject [_model, eyePos player, true];
                };
            };
            if (!isNull _ghost) then { _ghost call FAC_build_clearGhostCollision };
            missionNamespace setVariable ["FAC_build_class", _class];
            missionNamespace setVariable ["FAC_build_ghostObj", _ghost];
            if (isNull _ghost) then { _failed = true };
        };

        if (_failed) exitWith {
            [] call FAC_build_placeTeardown;
            missionNamespace setVariable ["FAC_build_spawnLive", false];
            systemChat "Could not preview that piece.";
            cutText ["", "BLACK IN", _fade];
            [] spawn {
                sleep 0.15;
                if (!isNil "FAC_buildGui_fnc") then { ["open", []] call FAC_buildGui_fnc };
            };
        };

        [] call FAC_build_bindInput;
        [false] call FAC_build_placeStatus;
        cutText ["", "BLACK IN", _fade];

        private _reopen = false;
        private _run = true;
        while { _run } do {
            sleep 0.05;
            if (missionNamespace getVariable ["FAC_build_cancel", false] || { !alive player }) exitWith {
                _run = false;
            };
            if (missionNamespace getVariable ["FAC_build_confirm", false]) then {
                missionNamespace setVariable ["FAC_build_confirm", false];
                if ([] call FAC_build_placeOne) then {
                    if !(missionNamespace getVariable ["FAC_build_optMulti", false]) then {
                        _reopen = true;
                        _run = false;
                    };
                };
            };
        };

        private _backToMenu = _reopen || { missionNamespace getVariable ["FAC_build_cancel", false] };
        cutText ["", "BLACK OUT", _fade];
        sleep (_fade max 0.1);
        [] call FAC_build_placeTeardown;
        missionNamespace setVariable ["FAC_build_spawnLive", false];
        cutText ["", "BLACK IN", _fade];
        if (_backToMenu && { alive player }) then {
            [] spawn {
                sleep 0.15;
                if (!isNil "FAC_buildGui_fnc") then { ["open", []] call FAC_buildGui_fnc };
            };
        };
    };
};

FAC_buildGui_comboText = {
    params ["_ctrl", ["_fallback", "All"]];
    if (isNull _ctrl) exitWith { _fallback };
    private _i = lbCurSel _ctrl;
    if (_i < 0) exitWith { _fallback };
    _ctrl lbText _i
};

FAC_buildGui_uniqueSorted = {
    params ["_vals"];
    private _seen = createHashMap;
    private _out = [];
    {
        if (_x isEqualType "" && { _x != "" } && { !(_seen getOrDefault [_x, false]) }) then {
            _seen set [_x, true];
            _out pushBack _x;
        };
    } forEach _vals;
    _out sort true;
    _out
};

FAC_buildGui_setCombo = {
    params ["_ctrl", "_items", ["_keep", ""]];
    if (isNull _ctrl) exitWith {};
    missionNamespace setVariable ["FAC_build_guiFilling", true];
    lbClear _ctrl;
    private _sel = 0;
    {
        private _i = _ctrl lbAdd _x;
        if (_x == _keep) then { _sel = _i };
    } forEach _items;
    if ((lbSize _ctrl) > 0) then { _ctrl lbSetCurSel _sel };
    missionNamespace setVariable ["FAC_build_guiFilling", false];
};

FAC_buildGui_fillSubs = {
    params [["_keep", ""]];
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _cat = [_d displayCtrl FAC_buildGui_CAT] call FAC_buildGui_comboText;
    private _subCtrl = _d displayCtrl FAC_buildGui_SUB;
    if (_keep == "") then { _keep = [_subCtrl] call FAC_buildGui_comboText };
    private _subs = ["All"];
    if (_cat != "All") then {
        private _names = (([] call FADE_build_fortRows) select { (_x select 5) == _cat }) apply { _x select 6 };
        _subs append ([_names] call FAC_buildGui_uniqueSorted);
    };
    [_subCtrl, _subs, _keep] call FAC_buildGui_setCombo;
};

FAC_buildGui_baseStream = {
    ([] call FADE_build_requireOn) && { (missionNamespace getVariable ["FAC_build_stream", "fort"]) == "base" }
};

FAC_buildGui_fillList = {
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _baseStream = [] call FAC_buildGui_baseStream;
    private _cat = [_d displayCtrl FAC_buildGui_CAT] call FAC_buildGui_comboText;
    private _sub = [_d displayCtrl FAC_buildGui_SUB] call FAC_buildGui_comboText;
    private _search = toLower (ctrlText (_d displayCtrl FAC_buildGui_SEARCH));
    private _list = _d displayCtrl FAC_buildGui_LIST;
    if (isNull _list) exitWith {};
    private _prefer = if (_baseStream) then {
        missionNamespace getVariable ["FAC_build_lastRole", ""]
    } else {
        missionNamespace getVariable ["FAC_build_lastClass", ""]
    };
    private _source = if (_baseStream) then {
        missionNamespace getVariable ["FADE_buildCatalogBase", []]
    } else {
        [] call FADE_build_fortRows
    };
    private _cap = 400;
    private _uncapped = _baseStream || { _cat != "All" } || { _sub != "All" };
    private _shown = 0;
    private _total = 0;
    private _sel = -1;
    missionNamespace setVariable ["FAC_build_guiFilling", true];
    lbClear _list;
    {
        if (!_baseStream && { _cat != "All" } && { (_x select 5) != _cat }) then { continue };
        if (!_baseStream && { _sub != "All" } && { (_x select 6) != _sub }) then { continue };
        if (!_baseStream && { _search != "" }) then {
            private _blob = toLower ((_x select 1) + " " + (_x select 0) + " " + (_x select 5) + " " + (_x select 6));
            if (_blob find _search < 0) then { continue };
        };
        _total = _total + 1;
        if (!_uncapped && { _shown >= _cap }) then { continue };
        private _label = _x select 1;
        if (!_baseStream && { _cat == "All" }) then {
            _label = format ["%1 > %2 > %3", _x select 5, _x select 6, _x select 1];
        };
        private _row = _list lbAdd _label;
        private _data = if (_baseStream) then { _x param [7, ""] } else { _x select 0 };
        _list lbSetData [_row, _data];
        if (_data == _prefer) then { _sel = _row };
        _shown = _shown + 1;
    } forEach _source;
    if (_sel < 0 && { (lbSize _list) > 0 }) then { _sel = 0 };
    if (_sel >= 0) then { _list lbSetCurSel _sel };
    missionNamespace setVariable ["FAC_build_guiFilling", false];
    private _note = if (_shown < _total) then {
        format ["%1 of %2", _shown, _total]
    } else {
        format ["%1 pieces", _total]
    };
    missionNamespace setVariable ["FAC_build_guiNote", _note];
    [] call FAC_buildGui_refresh;
};

FAC_buildGui_fillCats = {
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _names = ["All"];
    _names append ([(([] call FADE_build_fortRows) apply { _x select 5 })] call FAC_buildGui_uniqueSorted);
    private _keepCat = "All";
    private _keepSub = "All";
    private _prefer = missionNamespace getVariable ["FAC_build_lastClass", ""];
    if (_prefer != "") then {
        private _entry = [_prefer] call FADE_build_findEntry;
        if !(_entry isEqualTo []) then {
            _keepCat = _entry param [5, "All"];
            _keepSub = _entry param [6, "All"];
        };
    };
    [_d displayCtrl FAC_buildGui_CAT, _names, _keepCat] call FAC_buildGui_setCombo;
    [_keepSub] call FAC_buildGui_fillSubs;
    [] call FAC_buildGui_fillList;
};

FAC_buildGui_refresh = {
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _supply = _d displayCtrl 60956;
    private _detail = _d displayCtrl 60954;
    private _free = !([] call FADE_build_logisticsOn);
    if (!isNull _supply) then {
        private _base = if (_free) then {
            "Free"
        } else {
            format ["Supply %1", round (missionNamespace getVariable ["FADE_buildSupply", 0])]
        };
        private _note = missionNamespace getVariable ["FAC_build_guiNote", ""];
        if (_note == "") then {
            _supply ctrlSetText _base;
        } else {
            _supply ctrlSetText format ["%1. %2.", _base, _note];
        };
    };
    private _list = _d displayCtrl FAC_buildGui_LIST;
    if (isNull _list) exitWith {};
    private _idx = lbCurSel _list;
    if (_idx < 0) exitWith {
        if (!isNull _detail) then { _detail ctrlSetText "" };
        [_d, ""] call FAC_buildGui_setPreview;
    };
    private _data = _list lbData _idx;
    private _baseStream = [] call FAC_buildGui_baseStream;
    private _entry = if (_baseStream) then {
        [_data] call FADE_build_findBase
    } else {
        [_data] call FADE_build_findEntry
    };
    if (_entry isEqualTo []) exitWith { [_d, ""] call FAC_buildGui_setPreview };
    private _class = _entry param [0, ""];
    if (!isNull _detail) then {
        _entry params ["_entryClass", "_name", "_cost", "_bt", "_un", ["_cat", ""], ["_sub", ""]];
        private _path = format ["%1 > %2 > %3 (%4)", _cat, _sub, _name, _entryClass];
        if (_free) then {
            _detail ctrlSetText format ["%1  -  free", _path];
        } else {
            _detail ctrlSetText format ["%1  -  cost %2", _path, _cost];
        };
    };
    [_d, _class] call FAC_buildGui_setPreview;
};

FAC_buildGui_setPreview = {
    params ["_display", ["_class", ""]];
    if (isNull _display) exitWith {};
    private _pic = _display displayCtrl 60968;
    if (isNull _pic) exitWith {};
    if (_class == "") exitWith { _pic ctrlSetText "" };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _texture = getText (_cfg >> "editorPreview");
    if (_texture == "") then { _texture = getText (_cfg >> "picture") };
    if (_texture == "") then { _texture = getText (_cfg >> "icon") };
    _pic ctrlSetText _texture;
};

FAC_buildGui_fnc = {
    params ["_action", ["_params", []]];
    switch _action do {
        case "open": {
            if !(([] call FADE_build_anywhere) || { [] call FAC_aceSelf_nearPlayerBase }) exitWith {
                systemChat "Move closer to base to build.";
            };
            if !( ["FAC_playerCanBuild"] call FAC_lobbyParams_callAccess ) exitWith {
                systemChat "You can't build with the current lobby settings.";
            };
            if (!isNull (findDisplay FAC_buildGui_IDD)) exitWith {};
            if (!isNil "FAC_build_ghostStop") then { [] call FAC_build_ghostStop };
            if (!createDialog "RscDisplayBuild") then {
                systemChat "BUILD GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _d = findDisplay FAC_buildGui_IDD;
            if (isNull _d) exitWith {};
            [_d, [] call FAC_buildGui_activeSpec] call FAC_gui_build;
            [] call FAC_buildGui_syncOpts;
            [] call FAC_buildGui_syncStream;
            if ([] call FAC_buildGui_baseStream) then {
                [] call FAC_buildGui_fillList;
            } else {
                missionNamespace setVariable ["FAC_build_stream", "fort"];
                [] call FAC_buildGui_fillCats;
            };
            _d displayAddEventHandler ["KeyDown", {
                params ["_disp", "_key"];
                if (_key != 1) exitWith { false };
                closeDialog 0;
                true
            }];
        };
        case "catChanged": {
            if (missionNamespace getVariable ["FAC_build_guiFilling", false]) exitWith {};
            [] call FAC_buildGui_fillSubs;
            [] call FAC_buildGui_fillList;
        };
        case "subChanged";
        case "searchChanged": {
            if (missionNamespace getVariable ["FAC_build_guiFilling", false]) exitWith {};
            [] call FAC_buildGui_fillList;
        };
        case "selChanged": {
            if (missionNamespace getVariable ["FAC_build_guiFilling", false]) exitWith {};
            [] call FAC_buildGui_refresh;
        };
        case "place": {
            private _d = findDisplay FAC_buildGui_IDD;
            if (isNull _d) exitWith {};
            private _list = _d displayCtrl FAC_buildGui_LIST;
            private _idx = lbCurSel _list;
            if (_idx < 0) exitWith { systemChat "Pick a piece first."; };
            private _data = _list lbData _idx;
            private _class = _data;
            private _role = "";
            private _missing = false;
            if ([] call FAC_buildGui_baseStream) then {
                _role = _data;
                private _entry = [_role] call FADE_build_findBase;
                if (_entry isEqualTo []) then {
                    _missing = true;
                } else {
                    _class = _entry select 0;
                };
            };
            if (_missing || { _class == "" }) exitWith { systemChat "Pick a piece first." };
            missionNamespace setVariable ["FAC_build_lastClass", _class];
            missionNamespace setVariable ["FAC_build_lastRole", _role];
            closeDialog 0;
            [_class] call FAC_build_ghostStart;
        };
        case "setTab": {
            _params params [["_tab", "build"]];
            private _d = findDisplay FAC_buildGui_IDD;
            if (isNull _d) exitWith {};
            [_d, _tab] call FAC_gui_showPage;
            if (_tab == "placed") then { [player] remoteExec ["FADE_build_sendList", 2] };
        };
        case "headerRefresh": {
            private _d = findDisplay FAC_buildGui_IDD;
            if (isNull _d) exitWith {};
            if ((_d getVariable ["FAC_gui_page", "build"]) == "placed") then {
                [player] remoteExec ["FADE_build_sendList", 2];
            } else {
                if ([] call FAC_buildGui_baseStream) then {
                    [] call FAC_buildGui_fillList;
                } else {
                    [] call FAC_buildGui_fillCats;
                };
            };
        };
        case "deletePlaced": {
            private _d = findDisplay FAC_buildGui_IDD;
            if (isNull _d) exitWith {};
            private _list = _d displayCtrl 60964;
            if (isNull _list) exitWith {};
            private _idx = lbCurSel _list;
            if (_idx < 0) exitWith { systemChat "Select a piece first." };
            private _id = _list lbData _idx;
            if (_id == "") exitWith { systemChat "Select a piece first." };
            [player, _id] remoteExec ["FADE_build_remove", 2];
            [] spawn {
                sleep 0.2;
                if (isNull (findDisplay 60950)) exitWith {};
                [player] remoteExec ["FADE_build_sendList", 2];
            };
        };
        case "setStream": {
            _params params [["_stream", "fort"]];
            if (_stream != "base" || { !([] call FADE_build_requireOn) }) then { _stream = "fort" };
            missionNamespace setVariable ["FAC_build_stream", _stream];
            [] call FAC_buildGui_syncStream;
            if (_stream == "base") then {
                [] call FAC_buildGui_fillList;
            } else {
                [] call FAC_buildGui_fillCats;
            };
        };
        case "toggleOpt": {
            _params params [["_which", ""]];
            switch _which do {
                case "sim": {
                    missionNamespace setVariable ["FAC_build_optSim", !(missionNamespace getVariable ["FAC_build_optSim", true])];
                };
                case "damage": {
                    missionNamespace setVariable ["FAC_build_optDamage", !(missionNamespace getVariable ["FAC_build_optDamage", true])];
                };
                case "simple": {
                    missionNamespace setVariable ["FAC_build_optSimple", !(missionNamespace getVariable ["FAC_build_optSimple", false])];
                };
                case "multi": {
                    missionNamespace setVariable ["FAC_build_optMulti", !(missionNamespace getVariable ["FAC_build_optMulti", false])];
                };
            };
            [] call FAC_buildGui_syncOpts;
        };
    };
};

FAC_buildGui_activeSpec = {
    if ([] call FADE_build_requireOn) exitWith { FAC_gui_spec_build };
    private _out = [];
    {
        if ((_x param [0, ""]) == "page" && { (_x param [1, ""]) == "build" }) then {
            private _body = _x param [2, []];
            private _left = + (_body param [1, []]);
            if ((count _left) > 0 && { ((_left select 0) param [0, ""]) == "segments" }) then {
                _left deleteAt 0;
            };
            _out pushBack ["page", "build", ["columns", _left, _body param [2, []]]];
        } else {
            _out pushBack _x;
        };
    } forEach FAC_gui_spec_build;
    _out
};

FAC_buildGui_syncStream = {
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _base = [] call FAC_buildGui_baseStream;
    private _fortBtn = _d displayCtrl 60969;
    private _baseBtn = _d displayCtrl 60970;
    if (!isNull _fortBtn) then { [_fortBtn, !_base] call FAC_theme_applyTab };
    if (!isNull _baseBtn) then { [_baseBtn, _base] call FAC_theme_applyTab };
    {
        private _c = _d displayCtrl _x;
        if (!isNull _c) then { _c ctrlEnable (!_base) };
    } forEach [60961, 60962, 60963];
};

FAC_build_refillOpen = {
    if (isNull (findDisplay FAC_buildGui_IDD)) exitWith {};
    if ([] call FAC_buildGui_baseStream) then {
        [] call FAC_buildGui_fillList;
    } else {
        [] call FAC_buildGui_fillCats;
    };
};

FAC_buildGui_syncOpts = {
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _paint = {
        params ["_idc", "_on", "_name"];
        private _ctrl = _d displayCtrl _idc;
        if (isNull _ctrl) exitWith {};
        _ctrl ctrlSetText format ["%1: %2", _name, if (_on) then { "On" } else { "Off" }];
        _ctrl ctrlSetBackgroundColor ([if (_on) then { "primary" } else { "idle" }] call FAC_gui_styleColor);
    };
    [60980, missionNamespace getVariable ["FAC_build_optSim", true], "Simulation"] call _paint;
    [60981, missionNamespace getVariable ["FAC_build_optDamage", true], "Damage"] call _paint;
    [60982, missionNamespace getVariable ["FAC_build_optSimple", false], "Simple object"] call _paint;
    [60983, missionNamespace getVariable ["FAC_build_optMulti", false], "Place multiple"] call _paint;
};

FAC_buildGui_applyPlaced = {
    params [["_rows", []]];
    private _d = findDisplay FAC_buildGui_IDD;
    if (isNull _d) exitWith {};
    private _list = _d displayCtrl 60964;
    if (isNull _list) exitWith {};
    lbClear _list;
    {
        _x params ["_id", "_label"];
        private _i = _list lbAdd _label;
        _list lbSetData [_i, _id];
    } forEach _rows;
    if ((lbSize _list) > 0) then { _list lbSetCurSel 0 };
};

missionNamespace setVariable ["FAC_buildGui_fnc", FAC_buildGui_fnc];
missionNamespace setVariable ["FAC_buildGui_applyPlaced", FAC_buildGui_applyPlaced];
missionNamespace setVariable ["FAC_build_ghostStop", FAC_build_ghostStop];
missionNamespace setVariable ["FAC_build_ghostStart", FAC_build_ghostStart];
missionNamespace setVariable ["FAC_build_placeOne", FAC_build_placeOne];
missionNamespace setVariable ["FAC_buildGui_activeSpec", FAC_buildGui_activeSpec];
missionNamespace setVariable ["FAC_buildGui_syncStream", FAC_buildGui_syncStream];
missionNamespace setVariable ["FAC_build_refillOpen", FAC_build_refillOpen];
