// VehiclePlacement.sqf — shared pose check (client ghost + server) and the local placement camera.
// Compiled on the server from ServerGameplay.sqf and on the client from FAC_ensureVehicleGui.
// Ghost and camera are local. The real vehicle is created only by FADE_spawnVehicleAtPos.

FAC_vehiclePlacement_fadeSec = 0.45;

FADE_vehiclePlacement_basePos = {
    private _base = missionNamespace getVariable ["FADE_basePos", []];
    if (_base isEqualType objNull) then {
        _base = if (isNull _base) then { [] } else { getPosATL _base };
    };
    if (!(_base isEqualType []) || { count _base < 2 }) exitWith { [] };
    _base
};

FADE_vehiclePlacement_posOk = {
    params ["_pos"];
    if !(_pos isEqualType [] && { count _pos >= 3 }) exitWith { false };
    private _ok = true;
    for "_i" from 0 to 2 do {
        private _n = _pos select _i;
        if (!(_n isEqualType 0) || { !finite _n }) exitWith { _ok = false };
    };
    _ok
};

FADE_vehiclePlacement_classReason = {
    params ["_class"];
    if !(_class isEqualType "" && { _class != "" }) exitWith { "INVALID VEHICLE CLASS." };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {
        format ["UNKNOWN VEHICLE CLASS: %1", _class]
    };
    private _air = missionNamespace getVariable ["FADE_heliClasses", []];
    private _land = missionNamespace getVariable ["FADE_landVehicleClasses", []];
    if !(_class in _air || { _class in _land }) exitWith { "VEHICLE NOT AVAILABLE." };
    private _why = "";
    if (missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false]) then {
        private _allowed = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
        if (_allowed isEqualType [] && { count _allowed > 0 } && { !(_class in _allowed) }) then {
            _why = "VEHICLE NOT AVAILABLE.";
        };
    };
    if (_why != "") exitWith { _why };
    if !(_class isKindOf "Air" || { _class isKindOf "LandVehicle" }) exitWith { "VEHICLE NOT AVAILABLE." };
    ""
};

// Helipads, logics, and loose gear are not collisions. Terrain (objNull) is not ignored.
FADE_vehiclePlacement_ignored = {
    params ["_obj"];
    if (isNull _obj) exitWith { false };
    // The preview is local. On a listen server it still occupies the pose, so the real create would see it as a hit.
    if (_obj getVariable ["FAC_vehiclePlacement_isGhost", false]) exitWith { true };
    if (_obj isKindOf "Logic" || { _obj isKindOf "Helper_Base_F" }) exitWith { true };
    if (
        _obj isKindOf "WeaponHolder"
        || { _obj isKindOf "WeaponHolderSimulated" }
        || { _obj isKindOf "GroundWeaponHolder" }
    ) exitWith { true };
    if (_obj isKindOf "HeliH") exitWith { true };
    private _t = toLower (typeOf _obj);
    (_t find "helipad") >= 0 || { (_t find "helih") >= 0 } || { _t == "camera" }
};

FADE_vehiclePlacement_worldAabb = {
    params ["_obj"];
    private _bb = boundingBoxReal _obj;
    if !(_bb isEqualType [] && { count _bb >= 2 }) exitWith { [] };
    private _mn = _bb select 0;
    private _mx = _bb select 1;
    if !(_mn isEqualType [] && { _mx isEqualType [] && { count _mn >= 3 && { count _mx >= 3 } } }) exitWith { [] };
    private _wmin = [1e9, 1e9, 1e9];
    private _wmax = [-1e9, -1e9, -1e9];
    {
        private _px = _x;
        {
            private _py = _x;
            {
                private _w = _obj modelToWorldWorld [_px, _py, _x];
                _wmin set [0, (_wmin select 0) min (_w select 0)];
                _wmin set [1, (_wmin select 1) min (_w select 1)];
                _wmin set [2, (_wmin select 2) min (_w select 2)];
                _wmax set [0, (_wmax select 0) max (_w select 0)];
                _wmax set [1, (_wmax select 1) max (_w select 1)];
                _wmax set [2, (_wmax select 2) max (_w select 2)];
            } forEach [_mn select 2, _mx select 2];
        } forEach [_mn select 1, _mx select 1];
    } forEach [_mn select 0, _mx select 0];
    private _pad = 0.2;
    for "_i" from 0 to 2 do {
        private _lo = (_wmin select _i) + _pad;
        private _hi = (_wmax select _i) - _pad;
        if (_lo > _hi) then {
            private _mid = ((_wmin select _i) + (_wmax select _i)) / 2;
            _lo = _mid;
            _hi = _mid;
        };
        _wmin set [_i, _lo];
        _wmax set [_i, _hi];
    };
    [_wmin, _wmax]
};

FADE_vehiclePlacement_aabbHit = {
    params ["_a0", "_a1", "_b0", "_b1"];
    private _hit = true;
    for "_i" from 0 to 2 do {
        if (((_a1 select _i) < (_b0 select _i)) || { (_b1 select _i) < (_a0 select _i) }) exitWith { _hit = false };
    };
    _hit
};

// Probe is already posed. Empty string means the pose is acceptable.
FADE_vehiclePlacement_poseReason = {
    params ["_probe"];
    if (isNull _probe) exitWith { "SPAWN FAILED." };
    private _agl = ASLToAGL (getPosASL _probe);
    private _base = [] call FADE_vehiclePlacement_basePos;
    if (count _base < 2) exitWith { "Player base is not set yet." };
    if ((_agl distance2D _base) > 1000) exitWith { "OUTSIDE BASE AREA." };
    private _aglZ = _agl select 2;
    if (_aglZ < -1 || { _aglZ > 80 }) exitWith { "HEIGHT OUT OF RANGE." };
    private _probeClass = typeOf _probe;
    if (_probeClass == "") then {
        _probeClass = _probe getVariable ["FAC_vehiclePlacement_ghostClass", ""];
    };
    if (_probeClass isKindOf "LandVehicle" && { surfaceIsWater _agl }) exitWith { "CANNOT PLACE ON WATER." };

    private _blocked = false;
    private _mine = [_probe] call FADE_vehiclePlacement_worldAabb;
    if (count _mine == 2) then {
        private _dx = abs (((_mine select 1) select 0) - ((_mine select 0) select 0));
        private _dy = abs (((_mine select 1) select 1) - ((_mine select 0) select 1));
        private _rad = ((_dx max _dy) * 0.5) + 4;
        private _near = nearestObjects [
            _agl,
            ["Air", "LandVehicle", "Ship", "Man", "StaticWeapon"],
            _rad
        ];
        {
            if (isNull _x || { _x == _probe }) then { continue };
            if (_x isKindOf "Man" && { !alive _x }) then { continue };
            if ([_x] call FADE_vehiclePlacement_ignored) then { continue };
            private _box = [_x] call FADE_vehiclePlacement_worldAabb;
            if (count _box < 2) then { continue };
            if ([_mine select 0, _mine select 1, _box select 0, _box select 1] call FADE_vehiclePlacement_aabbHit) exitWith {
                _blocked = true
            };
        } forEach _near;
    };
    if (_blocked) exitWith { "BLOCKED." };

    private _bb = boundingBoxReal _probe;
    if (_bb isEqualType [] && { count _bb >= 2 }) then {
        private _mn = _bb select 0;
        private _mx = _bb select 1;
        private _spanX = abs ((_mx select 0) - (_mn select 0));
        private _spanY = abs ((_mx select 1) - (_mn select 1));
        private _insetX = (_spanX * 0.2) min 0.45;
        private _insetY = (_spanY * 0.2) min 0.45;
        private _x0 = (_mn select 0) + _insetX;
        private _x1 = (_mx select 0) - _insetX;
        private _y0 = (_mn select 1) + _insetY;
        private _y1 = (_mx select 1) - _insetY;
        private _z0 = (_mn select 2) + 0.45;
        private _z1 = (_mx select 2) - 0.15;
        if (_z1 < _z0) then { _z1 = _z0 + 0.25 };
        private _cx = ((_mn select 0) + (_mx select 0)) / 2;
        private _cy = ((_mn select 1) + (_mx select 1)) / 2;
        private _cz = (_z0 + _z1) / 2;
        private _segs = [
            [[_cx, _cy, _z0], [_cx, _cy, _z1]],
            [[_x0, _y0, _z0], [_x0, _y0, _z1]],
            [[_x0, _y1, _z0], [_x0, _y1, _z1]],
            [[_x1, _y0, _z0], [_x1, _y0, _z1]],
            [[_x1, _y1, _z0], [_x1, _y1, _z1]],
            [[_x0, _cy, _cz], [_x1, _cy, _cz]],
            [[_cx, _y0, _cz], [_cx, _y1, _cz]]
        ];
        {
            if (_blocked) exitWith {};
            _x params ["_m0", "_m1"];
            private _a = _probe modelToWorldWorld _m0;
            private _b = _probe modelToWorldWorld _m1;
            private _hits = lineIntersectsSurfaces [_a, _b, _probe, player, true, 4, "GEOM", "NONE"];
            {
                private _hitObj = _x select 2;
                if (!isNull _hitObj && { _hitObj == _probe }) then { continue };
                private _parent = if (count _x > 3) then { _x select 3 } else { objNull };
                private _skip = (!isNull _hitObj) && { [_hitObj] call FADE_vehiclePlacement_ignored };
                if (_skip && { !isNull _parent }) then {
                    _skip = [_parent] call FADE_vehiclePlacement_ignored;
                };
                if (!_skip) exitWith { _blocked = true };
            } forEach _hits;
        } forEach _segs;
    };
    if (_blocked) exitWith { "BLOCKED." };
    ""
};

// Optional 4th arg is an existing local probe (the ghost). Otherwise a local probe is created and deleted.
FADE_vehiclePlacement_reason = {
    params ["_class", "_posASL", ["_dir", 0], ["_probe", objNull]];
    private _classReason = [_class] call FADE_vehiclePlacement_classReason;
    if (_classReason != "") exitWith { _classReason };
    if !([_posASL] call FADE_vehiclePlacement_posOk) exitWith { "INVALID POSITION." };
    if !(_dir isEqualType 0) then { _dir = 0 };
    private _madeProbe = false;
    if (isNull _probe) then {
        // Local only. Created in the air so the hull never touches the ground, then moved with simulation off.
        _probe = _class createVehicleLocal [0, 0, 1000];
        _madeProbe = true;
        if (!isNull _probe) then {
            _probe allowDamage false;
            _probe enableSimulation false;
            deleteVehicleCrew _probe;
        };
    };
    if (isNull _probe) exitWith { "SPAWN FAILED." };
    _probe setPosASL _posASL;
    _probe setVectorDirAndUp [[sin _dir, cos _dir, 0], [0, 0, 1]];
    private _why = [_probe] call FADE_vehiclePlacement_poseReason;
    if (_madeProbe) then {
        // Move it away before delete. A probe deleted in place still occupies the hull for the real create.
        _probe setPosASL [0, 0, 1000];
        deleteVehicle _probe;
    };
    _why
};

FADE_vehiclePlacement_createAt = {
    params ["_class", "_posASL", ["_dir", 0]];
    if (!isServer) exitWith { objNull };
    private _why = [_class, _posASL, _dir] call FADE_vehiclePlacement_reason;
    if (_why != "") exitWith {
        diag_log format ["[FADE] vehicle placement create blocked: %1 (%2)", _why, _class];
        objNull
    };
    // NONE looks for a suitable spot and drops a land vehicle onto the ground during create,
    // which damages the hull before the next line. CAN_COLLIDE keeps this air position.
    // https://community.bistudio.com/wiki/createVehicle
    private _atl = ASLToATL _posASL;
    _atl set [2, (_atl select 2) + 100];
    private _veh = createVehicle [_class, _atl, [], 0, "CAN_COLLIDE"];
    if (isNull _veh) exitWith { objNull };
    _veh allowDamage false;
    _veh enableSimulationGlobal false;
    _veh setPosASL _posASL;
    _veh setVectorDirAndUp [[sin _dir, cos _dir, 0], [0, 0, 1]];
    _veh setVelocity [0, 0, 0];
    _veh setFuel 1;
    _veh setVehicleAmmo 1;
    [_veh] call FADE_pylon_sanitizeVehicle;
    deleteVehicleCrew _veh;
    [_veh] spawn {
        params ["_veh"];
        sleep 0.1;
        if (isNull _veh) exitWith {};
        _veh enableSimulationGlobal true;
        _veh setVelocity [0, 0, 0];
        sleep 1;
        if (isNull _veh || { !alive _veh }) exitWith {};
        if ((vectorMagnitude (velocity _veh)) < 1.5) then {
            _veh setVelocity [0, 0, 0];
        };
        _veh allowDamage true;
    };
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
    _veh
};

FADE_spawnVehicleAtPos = {
    if (!isServer) exitWith {};
    params ["_class", "_player", "_posASL", ["_dir", 0]];
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if ([_player] call FADE_base_denyUntilDefined) exitWith {};
    if !(_class isEqualType "") then { _class = "" };
    if !(_dir isEqualType 0) then { _dir = 0 };
    private _why = [_class, _posASL, _dir] call FADE_vehiclePlacement_reason;
    if (_why != "") exitWith {
        [_why] remoteExec ["systemChat", _player];
    };
    private _veh = [_class, _posASL, _dir] call FADE_vehiclePlacement_createAt;
    if (isNull _veh) exitWith {
        private _name = if (_class == "") then { "VEHICLE" } else { _class };
        [format ["SPAWN FAILED. %1 INVALID OR MOD NOT LOADED.", _name]] remoteExec ["systemChat", _player];
    };
    private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_displayName == "") then { _displayName = _class };
    [format ["%1 SPAWNED.", _displayName]] remoteExec ["systemChat", _player];
};

FAC_vehiclePlacement_status = {
    params ["_clear"];
    private _state = if (_clear) then { "Clear" } else { "Blocked" };
    titleText [
        format [
            "%1. WASD moves the camera. Mouse looks. Wheel sets distance. Q and E rotate. Page Up and Page Down raise aircraft. Space places. Esc cancels.",
            _state
        ],
        "PLAIN DOWN",
        0.3
    ];
    // Default PLAIN DOWN fades in a couple of seconds. A long fade-out keeps the keys on screen.
    titleFadeOut 9999;
};

// Fixed distance in front of the camera yaw, then straight down onto the surface.
// Pitch is ignored, so looking up or down does not move the ghost closer.
// The model origin sits on that surface. Lifting by the bounding box leaves the wheels in the air.
FAC_vehiclePlacement_ghostAsl = {
    params ["_ghost"];
    private _dist = missionNamespace getVariable ["FAC_vehiclePlacement_dist", 12];
    private _yaw = missionNamespace getVariable ["FAC_vehiclePlacement_camYaw", 0];
    private _camAgl = ASLToAGL (missionNamespace getVariable ["FAC_vehiclePlacement_camPos", [0, 0, 0]]);
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
    private _raise = missionNamespace getVariable ["FAC_vehiclePlacement_raise", 0];
    [_asl select 0, _asl select 1, (_asl select 2) + _raise]
};

FAC_vehiclePlacement_teardown = {
    missionNamespace setVariable ["FAC_vehiclePlacement_active", false];
    private _frame = missionNamespace getVariable ["FAC_vehiclePlacement_frameEh", -1];
    if (_frame >= 0) then { removeMissionEventHandler ["EachFrame", _frame] };
    missionNamespace setVariable ["FAC_vehiclePlacement_frameEh", -1];
    private _disp = findDisplay 46;
    if (!isNull _disp) then {
        {
            _x params ["_type", "_id"];
            _disp displayRemoveEventHandler [_type, _id];
        } forEach (missionNamespace getVariable ["FAC_vehiclePlacement_dispEh", []]);
    };
    missionNamespace setVariable ["FAC_vehiclePlacement_dispEh", []];
    private _cam = missionNamespace getVariable ["FAC_vehiclePlacement_cam", objNull];
    if (!isNull _cam) then {
        _cam cameraEffect ["Terminate", "BACK"];
        camDestroy _cam;
    };
    missionNamespace setVariable ["FAC_vehiclePlacement_cam", objNull];
    showCinemaBorder true;
    private _ghost = missionNamespace getVariable ["FAC_vehiclePlacement_ghost", objNull];
    if (!isNull _ghost) then { deleteVehicle _ghost };
    missionNamespace setVariable ["FAC_vehiclePlacement_ghost", objNull];
    titleText ["", "PLAIN"];
    titleFadeOut 0;
};

FAC_vehiclePlacement_onFrame = {
    if !(missionNamespace getVariable ["FAC_vehiclePlacement_active", false]) exitWith {};
    private _cam = missionNamespace getVariable ["FAC_vehiclePlacement_cam", objNull];
    private _ghost = missionNamespace getVariable ["FAC_vehiclePlacement_ghost", objNull];
    if (isNull _cam || { isNull _ghost }) exitWith {};

    private _now = time;
    private _dt = _now - (missionNamespace getVariable ["FAC_vehiclePlacement_tick", _now]);
    missionNamespace setVariable ["FAC_vehiclePlacement_tick", _now];
    if (_dt < 0) then { _dt = 0 };
    if (_dt > 0.1) then { _dt = 0.1 };

    private _held = missionNamespace getVariable ["FAC_vehiclePlacement_held", []];
    private _shift = (42 in _held) || { 54 in _held };
    private _speed = if (_shift) then { 36 } else { 12 };
    private _camYaw = missionNamespace getVariable ["FAC_vehiclePlacement_camYaw", 0];
    private _pitch = missionNamespace getVariable ["FAC_vehiclePlacement_pitch", -15];
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
    private _camPos = missionNamespace getVariable ["FAC_vehiclePlacement_camPos", eyePos player];
    if ((vectorMagnitude _step) > 0) then {
        _camPos = _camPos vectorAdd ((vectorNormalized _step) vectorMultiply (_speed * _dt));
    };
    private _agl = ASLToAGL _camPos;
    private _base = [] call FADE_vehiclePlacement_basePos;
    if (count _base < 2) then { _base = _agl };
    private _dx = (_agl select 0) - (_base select 0);
    private _dy = (_agl select 1) - (_base select 1);
    private _dist = sqrt ((_dx * _dx) + (_dy * _dy));
    if (_dist > 1000 && { _dist > 0 }) then {
        private _s = 1000 / _dist;
        _agl = [(_base select 0) + (_dx * _s), (_base select 1) + (_dy * _s), _agl select 2];
    };
    _agl set [2, ((_agl select 2) max 2) min 80];
    _camPos = AGLToASL _agl;
    missionNamespace setVariable ["FAC_vehiclePlacement_camPos", _camPos];
    _cam setPosASL _camPos;
    _cam setVectorDirAndUp [_look, [0, 0, 1]];

    if (!isNull player) then {
        player setDir (missionNamespace getVariable ["FAC_vehiclePlacement_playerDir", getDir player]);
    };

    private _raise = missionNamespace getVariable ["FAC_vehiclePlacement_raise", 0];
    if (_ghost isKindOf "Air") then {
        if (201 in _held) then { _raise = (_raise + (8 * _dt)) min 30 };
        if (209 in _held) then { _raise = (_raise - (8 * _dt)) max 0 };
    } else {
        _raise = 0;
    };
    missionNamespace setVariable ["FAC_vehiclePlacement_raise", _raise];

    private _surface = [_ghost] call FAC_vehiclePlacement_ghostAsl;
    if (count _surface >= 3) then {
        private _dir = (missionNamespace getVariable ["FAC_vehiclePlacement_camYaw", 0]) + (missionNamespace getVariable ["FAC_vehiclePlacement_yaw", 0]);
        _ghost setPosASL _surface;
        _ghost setVectorDirAndUp [[sin _dir, cos _dir, 0], [0, 0, 1]];
        // Moving the preview can restore the geometry shape. Keep PhysX collision off.
        _ghost call FAC_vehiclePlacement_clearGhostCollision;
    };

    if (_now >= (missionNamespace getVariable ["FAC_vehiclePlacement_nextCheck", 0])) then {
        missionNamespace setVariable ["FAC_vehiclePlacement_nextCheck", _now + 0.1];
        private _ghostClass = typeOf _ghost;
        if (_ghostClass == "") then {
            _ghostClass = _ghost getVariable ["FAC_vehiclePlacement_ghostClass", ""];
        };
        private _why = [_ghostClass, getPosASL _ghost, getDir _ghost, _ghost] call FADE_vehiclePlacement_reason;
        private _clear = _why == "";
        missionNamespace setVariable ["FAC_vehiclePlacement_blocked", !_clear];
        private _was = missionNamespace getVariable ["FAC_vehiclePlacement_wasClear", true];
        if (_was isEqualTo _clear) exitWith {};
        missionNamespace setVariable ["FAC_vehiclePlacement_wasClear", _clear];
        [_clear] call FAC_vehiclePlacement_status;
    };
};

FAC_vehiclePlacement_bindInput = {
    private _disp = findDisplay 46;
    if (isNull _disp) exitWith {};
    private _ids = [];
    private _down = _disp displayAddEventHandler ["KeyDown", {
        params ["_d", "_key"];
        if !(missionNamespace getVariable ["FAC_vehiclePlacement_active", false]) exitWith { false };
        private _used = _key in [1, 16, 17, 18, 30, 31, 32, 42, 54, 57, 201, 209];
        if (_used) then {
            private _held = missionNamespace getVariable ["FAC_vehiclePlacement_held", []];
            if !(_key in _held) then {
                _held pushBack _key;
                missionNamespace setVariable ["FAC_vehiclePlacement_held", _held];
            };
            if (_key == 1) then { missionNamespace setVariable ["FAC_vehiclePlacement_cancel", true] };
            if (_key == 57 && { !(missionNamespace getVariable ["FAC_vehiclePlacement_spaceDown", false]) }) then {
                missionNamespace setVariable ["FAC_vehiclePlacement_spaceDown", true];
                missionNamespace setVariable ["FAC_vehiclePlacement_confirm", true];
            };
            if (_key == 16 || { _key == 18 }) then {
                private _yaw = missionNamespace getVariable ["FAC_vehiclePlacement_yaw", 0];
                _yaw = _yaw + (if (_key == 16) then { -5 } else { 5 });
                if (_yaw < 0) then { _yaw = _yaw + 360 };
                if (_yaw >= 360) then { _yaw = _yaw - 360 };
                missionNamespace setVariable ["FAC_vehiclePlacement_yaw", _yaw];
            };
        };
        _used
    }];
    _ids pushBack ["KeyDown", _down];
    private _up = _disp displayAddEventHandler ["KeyUp", {
        params ["_d", "_key"];
        private _held = missionNamespace getVariable ["FAC_vehiclePlacement_held", []];
        missionNamespace setVariable ["FAC_vehiclePlacement_held", _held - [_key]];
        if (_key == 57) then { missionNamespace setVariable ["FAC_vehiclePlacement_spaceDown", false] };
        false
    }];
    _ids pushBack ["KeyUp", _up];
    private _move = _disp displayAddEventHandler ["MouseMoving", {
        params ["_d", "_dx", "_dy"];
        if !(missionNamespace getVariable ["FAC_vehiclePlacement_active", false]) exitWith { false };
        private _camYaw = missionNamespace getVariable ["FAC_vehiclePlacement_camYaw", 0];
        private _pitch = missionNamespace getVariable ["FAC_vehiclePlacement_pitch", -15];
        missionNamespace setVariable ["FAC_vehiclePlacement_camYaw", _camYaw + (_dx * 0.15)];
        missionNamespace setVariable ["FAC_vehiclePlacement_pitch", ((_pitch - (_dy * 0.15)) max -70) min 50];
        true
    }];
    _ids pushBack ["MouseMoving", _move];
    private _wheel = _disp displayAddEventHandler ["MouseZChanged", {
        params ["_d", "_scroll"];
        if !(missionNamespace getVariable ["FAC_vehiclePlacement_active", false]) exitWith { false };
        private _dist = missionNamespace getVariable ["FAC_vehiclePlacement_dist", 12];
        _dist = (_dist + (_scroll * 0.5)) max 6 min 40;
        missionNamespace setVariable ["FAC_vehiclePlacement_dist", _dist];
        true
    }];
    _ids pushBack ["MouseZChanged", _wheel];
    missionNamespace setVariable ["FAC_vehiclePlacement_dispEh", _ids];
    private _frame = addMissionEventHandler ["EachFrame", { [] call FAC_vehiclePlacement_onFrame }];
    missionNamespace setVariable ["FAC_vehiclePlacement_frameEh", _frame];
};

// Local preview only. A simple object has no PhysX body of its own, but its Geometry LOD
// is still a solid shape, and a real vehicle hits that shape. false drops PhysX and geometry
// collision. Roadway (walk-on) LOD stays. Local effect, and the preview is local.
// The command strings stay compiled because the SQF-VM command list predates Arma 2.18.
// https://community.bistudio.com/wiki/createSimpleObject
// https://community.bistudio.com/wiki/setPhysicsCollisionFlag
// https://community.bistudio.com/wiki/getPhysicsCollisionFlag
FAC_vehiclePlacement_clearGhostCollision = compile "_this setPhysicsCollisionFlag false";
FAC_vehiclePlacement_ghostCollisionFlag = compile "getPhysicsCollisionFlag _this";
FAC_vehiclePlacement_createGhost = {
    params ["_class", "_posASL"];
    private _ghost = createSimpleObject [_class, _posASL, true];
    if (isNull _ghost) then {
        private _model = getText (configFile >> "CfgVehicles" >> _class >> "model");
        if (_model != "") then {
            _ghost = createSimpleObject [_model, _posASL, true];
        };
    };
    if (!isNull _ghost) then {
        _ghost call FAC_vehiclePlacement_clearGhostCollision;
        _ghost setVariable ["FAC_vehiclePlacement_isGhost", true];
        _ghost setVariable ["FAC_vehiclePlacement_ghostClass", _class];
    };
    _ghost
};

FAC_vehiclePlacement_returnToGui = {
    params ["_returnTab", "_category", "_class"];
    if (!alive player) exitWith {};
    missionNamespace setVariable ["FAC_vehicleGui_restore", [_returnTab, _category, _class]];
    [] call FAC_ensureVehicleGui;
    ["open", []] call (missionNamespace getVariable ["FAC_vehicleGui_fnc", {}]);
};

FAC_vehiclePlacement_start = {
    params ["_class", ["_returnTab", "new"], ["_category", "aircraft"]];
    if (!hasInterface) exitWith {};
    if (missionNamespace getVariable ["FAC_vehiclePlacement_active", false]) exitWith {};
    if !(_class isEqualType "" && { _class != "" }) exitWith {};
    missionNamespace setVariable ["FAC_vehiclePlacement_active", true];
    [_class, _returnTab, _category] spawn {
        params ["_class", "_returnTab", "_category"];
        private _fade = missionNamespace getVariable ["FAC_vehiclePlacement_fadeSec", 0.45];
        missionNamespace setVariable ["FAC_vehiclePlacement_cancel", false];
        missionNamespace setVariable ["FAC_vehiclePlacement_confirm", false];
        missionNamespace setVariable ["FAC_vehiclePlacement_spaceDown", false];
        missionNamespace setVariable ["FAC_vehiclePlacement_held", []];
        missionNamespace setVariable ["FAC_vehiclePlacement_raise", 0];
        missionNamespace setVariable ["FAC_vehiclePlacement_dist", 12];
        missionNamespace setVariable ["FAC_vehiclePlacement_blocked", true];
        missionNamespace setVariable ["FAC_vehiclePlacement_wasClear", "unset"];
        missionNamespace setVariable ["FAC_vehiclePlacement_nextCheck", 0];
        missionNamespace setVariable ["FAC_vehiclePlacement_yaw", 0];
        missionNamespace setVariable ["FAC_vehiclePlacement_camYaw", getDir player];
        missionNamespace setVariable ["FAC_vehiclePlacement_pitch", -15];
        missionNamespace setVariable ["FAC_vehiclePlacement_playerDir", getDir player];
        missionNamespace setVariable ["FAC_vehiclePlacement_tick", time];
        missionNamespace setVariable ["FAC_vehiclePlacement_camPos", eyePos player];

        cutText ["", "BLACK OUT", _fade];
        sleep (_fade max 0.1);
        if (!isNull (findDisplay 60001)) then { closeDialog 0 };

        private _cam = "camera" camCreate (ASLToAGL (eyePos player));
        missionNamespace setVariable ["FAC_vehiclePlacement_cam", _cam];
        if (isNull _cam) exitWith {
            [] call FAC_vehiclePlacement_teardown;
            [_returnTab, _category, _class] call FAC_vehiclePlacement_returnToGui;
            cutText ["", "BLACK IN", _fade];
        };
        _cam cameraEffect ["Internal", "BACK"];
        showCinemaBorder false;
        _cam setPosASL (missionNamespace getVariable ["FAC_vehiclePlacement_camPos", eyePos player]);
        private _yaw0 = missionNamespace getVariable ["FAC_vehiclePlacement_camYaw", 0];
        private _pitch0 = missionNamespace getVariable ["FAC_vehiclePlacement_pitch", -15];
        _cam setVectorDirAndUp [[
            (sin _yaw0) * (cos _pitch0),
            (cos _yaw0) * (cos _pitch0),
            sin _pitch0
        ], [0, 0, 1]];

        private _ghost = [_class, eyePos player] call FAC_vehiclePlacement_createGhost;
        missionNamespace setVariable ["FAC_vehiclePlacement_ghost", _ghost];
        if (isNull _ghost) exitWith {
            [] call FAC_vehiclePlacement_teardown;
            [_returnTab, _category, _class] call FAC_vehiclePlacement_returnToGui;
            cutText ["", "BLACK IN", _fade];
        };

        [] call FAC_vehiclePlacement_bindInput;
        [false] call FAC_vehiclePlacement_status;
        cutText ["", "BLACK IN", _fade];

        private _run = true;
        while { _run } do {
            sleep 0.05;
            if (missionNamespace getVariable ["FAC_vehiclePlacement_cancel", false] || { !alive player }) exitWith {
                missionNamespace setVariable ["FAC_vehiclePlacement_cancel", true];
                _run = false;
            };
            if (missionNamespace getVariable ["FAC_vehiclePlacement_confirm", false]) then {
                missionNamespace setVariable ["FAC_vehiclePlacement_confirm", false];
                if !(missionNamespace getVariable ["FAC_vehiclePlacement_blocked", true]) then {
                    private _ghostNow = missionNamespace getVariable ["FAC_vehiclePlacement_ghost", objNull];
                    if (!isNull _ghostNow) then {
                        private _pos = getPosASL _ghostNow;
                        private _dirNow = getDir _ghostNow;
                        // Park the preview off the pose before the server create. The next frame puts it back.
                        // On a listen server the create must run now, while the preview is still parked.
                        _ghostNow setPosASL [0, 0, 1500];
                        if (isServer) then {
                            [_class, player, _pos, _dirNow] call FADE_spawnVehicleAtPos;
                        } else {
                            [_class, player, _pos, _dirNow] remoteExec ["FADE_spawnVehicleAtPos", 2];
                        };
                        private _displayName = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
                        if (_displayName == "") then { _displayName = _class };
                        systemChat format ["Requesting spawn: %1...", _displayName];
                    };
                    if !(missionNamespace getVariable ["FAC_vehicleGui_placeMultiple", false]) then {
                        _run = false;
                    };
                };
            };
        };

        cutText ["", "BLACK OUT", _fade];
        sleep (_fade max 0.1);
        [] call FAC_vehiclePlacement_teardown;
        [_returnTab, _category, _class] call FAC_vehiclePlacement_returnToGui;
        cutText ["", "BLACK IN", _fade];
    };
};
