// ServerGameplayBuild.sqf - place and remove player structures. Server only.
// createVehicle is global; special "CAN_COLLIDE" keeps the requested position.

if (!isServer) exitWith {};

call compile preprocessFileLineNumbers "rsc\BuildCommon.sqf";

if (isNil "FADE_build_registry") then {
    FADE_build_registry = createHashMap;
};

FADE_build_publishPool = {
    if (isNil "FADE_buildSupply") then {
        missionNamespace setVariable ["FADE_buildSupply", missionNamespace getVariable ["FADE_buildSupplyStart", 2000]];
    };
    publicVariable "FADE_buildSupply";
    publicVariable "FADE_buildRadius";
};

[] call FADE_build_publishPool;

FADE_build_chat = {
    params ["_player", "_msg"];
    if (isNull _player || { !isPlayer _player }) exitWith {};
    [_msg] remoteExec ["systemChat", _player];
};

FADE_build_place = {
    if (!isServer) exitWith { false };
    params [
        ["_player", objNull],
        ["_class", ""],
        ["_pos", []],
        ["_dir", 0],
        ["_up", [0, 0, 1]],
        ["_align", false],
        ["_sim", true],
        ["_damage", true],
        ["_simple", false]
    ];
    if (isNull _player) exitWith { false };
    if ([_player] call FADE_base_denyUntilDefined) exitWith { false };
    if !([_player] call FAC_playerCanBuild) exitWith {
        private _mode = (missionNamespace getVariable ["FAC_param_buildAccess", 1]) max 0 min 2;
        private _msg = if (_mode == 0) then {
            "Building is limited to engineers."
        } else {
            "Building is turned off."
        };
        [_player, _msg] call FADE_build_chat;
        false
    };
    private _entry = [_class] call FADE_build_findEntry;
    if (_entry isEqualTo []) exitWith {
        [_player, "That piece is not in the build list."] call FADE_build_chat;
        false
    };
    _entry params ["_entryClass", "_display", "_cost", "_buildTime", "_unlock"];
    if !(_pos isEqualType [] && { count _pos >= 3 } && { _dir isEqualType 0 }) exitWith { false };
    private _spot = [_entryClass, _pos, _dir, objNull] call FADE_build_spotBlocked;
    if (_spot != "") exitWith {
        private _msg = switch (_spot) do {
            case "water": { "Can't place that on water." };
            case "radius": { "Too far from base to build." };
            default { "That spot is blocked." };
        };
        [_player, _msg] call FADE_build_chat;
        false
    };
    private _charge = [] call FADE_build_logisticsOn;
    if (_charge && { (missionNamespace getVariable ["FADE_buildSupply", 0]) < _cost }) exitWith {
        [_player, "Not enough build supply."] call FADE_build_chat;
        false
    };

    private _obj = objNull;
    if (_simple) then {
        // Syntax 2. local false replicates the object. It can take a texture. addAction cannot.
        _obj = createSimpleObject [_entryClass, _pos, false];
    } else {
        _obj = createVehicle [_entryClass, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    };
    if (isNull _obj) exitWith {
        [_player, "Could not place that piece."] call FADE_build_chat;
        false
    };
    if (_simple) then {
        private _upVec = [0, 0, 1];
        if (_align && { _up isEqualType [] } && { count _up == 3 }) then {
            private _mag = vectorMagnitude _up;
            if (_mag > 0.01) then { _upVec = _up vectorMultiply (1 / _mag) };
        };
        _obj setVectorDirAndUp [[sin _dir, cos _dir, 0], _upVec];
        _obj setPosASL _pos;
    } else {
        _obj setPosATL _pos;
        _obj setDir _dir;
        if (_align && { _up isEqualType [] } && { count _up == 3 }) then {
            private _mag = vectorMagnitude _up;
            if (_mag > 0.01) then {
                _obj setVectorUp (_up vectorMultiply (1 / _mag));
            };
        };
        _obj allowDamage _damage;
        if (!_sim) then { _obj enableSimulationGlobal false };
    };
    _obj setVariable ["FADE_build_placed", true, true];
    _obj setVariable ["FADE_build_class", _entryClass, true];
    _obj setVariable ["FADE_build_cost", _cost, true];
    _obj setVariable ["FADE_build_state", "complete", true];
    _obj setVariable ["FADE_build_simple", _simple, true];

    private _id = netId _obj;
    if (_id == "") exitWith {
        deleteVehicle _obj;
        [_player, "Could not place that piece."] call FADE_build_chat;
        false
    };

    if (_charge) then {
        missionNamespace setVariable ["FADE_buildSupply", (missionNamespace getVariable ["FADE_buildSupply", 0]) - _cost];
        publicVariable "FADE_buildSupply";
    };

    private _rec = createHashMap;
    _rec set ["class", _entryClass];
    _rec set ["pos", _pos];
    _rec set ["cost", _cost];
    _rec set ["state", "complete"];
    _rec set ["owner", getPlayerUID _player];
    _rec set ["unlock", _unlock];
    _rec set ["buildTime", _buildTime];
    FADE_build_registry set [_id, _rec];
    [_obj] remoteExec ["FAC_build_clientAddRemove", 0, _obj];
    [_player, format ["Placed %1.", _display]] call FADE_build_chat;
    true
};
publicVariable "FADE_build_place";

FADE_build_remove = {
    if (!isServer) exitWith { false };
    params [["_player", objNull], ["_netId", ""]];
    if (isNull _player || { _netId == "" }) exitWith { false };
    if !([_player] call FAC_playerCanBuild) exitWith {
        [_player, "You can't remove structures with the current lobby settings."] call FADE_build_chat;
        false
    };
    private _obj = _netId call BIS_fnc_objectFromNetId;
    if (isNull _obj || { !(_obj getVariable ["FADE_build_placed", false]) }) exitWith { false };
    private _rec = FADE_build_registry getOrDefault [_netId, createHashMap];
    private _cost = _rec getOrDefault ["cost", _obj getVariable ["FADE_build_cost", 0]];
    if ([] call FADE_build_logisticsOn) then {
        missionNamespace setVariable ["FADE_buildSupply", (missionNamespace getVariable ["FADE_buildSupply", 0]) + _cost];
        publicVariable "FADE_buildSupply";
    };
    FADE_build_registry deleteAt _netId;
    deleteVehicle _obj;
    [_player, "Structure destroyed."] call FADE_build_chat;
    true
};
publicVariable "FADE_build_remove";

FADE_build_clearAll = {
    if (!isServer) exitWith { 0 };
    if (isNil "FADE_build_registry") then { FADE_build_registry = createHashMap };
    private _refund = 0;
    private _seen = [];
    {
        private _obj = _x call BIS_fnc_objectFromNetId;
        private _rec = FADE_build_registry getOrDefault [_x, createHashMap];
        private _cost = _rec getOrDefault ["cost", 0];
        if (!isNull _obj) then {
            if (_cost == 0) then { _cost = _obj getVariable ["FADE_build_cost", 0] };
            _seen pushBack _obj;
            deleteVehicle _obj;
        };
        _refund = _refund + _cost;
        FADE_build_registry deleteAt _x;
    } forEach (+ (keys FADE_build_registry));
    private _n = count _seen;
    {
        if (!isNull _x && { _x getVariable ["FADE_build_placed", false] } && { !(_x in _seen) }) then {
            _refund = _refund + (_x getVariable ["FADE_build_cost", 0]);
            deleteVehicle _x;
            _n = _n + 1;
        };
    } forEach (allMissionObjects "All");
    if (([] call FADE_build_logisticsOn) && { _refund > 0 }) then {
        missionNamespace setVariable ["FADE_buildSupply", (missionNamespace getVariable ["FADE_buildSupply", 0]) + _refund];
        publicVariable "FADE_buildSupply";
    };
    _n
};

FADE_build_signSet = {
    if (!isServer) exitWith { false };
    params [["_player", objNull], ["_netId", ""], ["_text", ""]];
    if (isNull _player || { _netId == "" }) exitWith { false };
    if !(_text isEqualType "") exitWith { false };
    if !([_player] call FAC_playerCanBuild) exitWith {
        [_player, "You can't write with the current lobby settings."] call FADE_build_chat;
        false
    };
    private _obj = _netId call BIS_fnc_objectFromNetId;
    if (isNull _obj || { !alive _obj } || { !(_obj getVariable ["FADE_build_placed", false]) }) exitWith { false };
    private _slot = [_obj] call FADE_build_writeSlot;
    if (_slot < 0) exitWith { false };
    private _clean = [_text] call FADE_build_signClean;
    // "#reset" (Arma 2.20) restores that slot. An empty path does not. Lower slots stay.
    private _tex = if (_clean == "") then {
        "#reset"
    } else {
        [_clean] call FADE_build_signTexture
    };
    _obj setObjectTextureGlobal [_slot, _tex];
    _obj setVariable ["FADE_build_signText", _clean, true];
    [_player, if (_clean == "") then { "Text cleared." } else { "Text updated." }] call FADE_build_chat;
    true
};
publicVariable "FADE_build_signSet";

missionNamespace setVariable ["FADE_build_registry", FADE_build_registry];
