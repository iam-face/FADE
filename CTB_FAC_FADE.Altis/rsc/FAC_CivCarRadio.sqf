// =============================================================================
// FAC_CivCarRadio.sqf — ambient road-car 3D radio (server + client)
// =============================================================================
// Server: [_song, "vehicle:<netId>", vol, dist] remoteExec ["FADE_civCarRadio_serverPlay", 2]
//          ["", "vehicle:<netId>"] remoteExec ["FADE_civCarRadio_serverPlay", 2] stops
// Client: playSound3D from @CTB mod CfgSFX (configFile). No JIP replay.
// Compiled on the server (ServerServices) and each client (initPlayerLocal).
// =============================================================================

if (missionNamespace getVariable ["FADE_civCarRadio_installed", false]) exitWith {};

FADE_civCarRadio_fnc_oggFromSfx = {
    params [["_song", ""]];
    if (_song == "") exitWith { ["", 1] };
    private _file = "";
    private _pitch = 1;
    if (isClass (configFile >> "CfgSFX" >> _song)) then {
        private _sounds = getArray (configFile >> "CfgSFX" >> _song >> "sounds");
        if !(_sounds isEqualTo []) then {
            private _arr = getArray (configFile >> "CfgSFX" >> _song >> (_sounds select 0));
            if (count _arr >= 1) then {
                _file = _arr select 0;
                _pitch = if (count _arr >= 3) then { _arr select 2 } else { 1 };
            };
        };
    };
    if (_file isEqualType "" && { count _file > 0 } && { (_file select [0, 1]) != "\" }) then {
        _file = "\" + _file;
    };
    [_file, _pitch]
};

// stopSound needs a scheduled context. playSound3D returns a numeric handle.
FADE_civCarRadio_fnc_stopPs3d = {
    params ["_id"];
    if (isNil "_id") exitWith {};
    if (_id isEqualType "") exitWith {};
    if (!(_id isEqualType 0)) exitWith {};
    stopSound _id;
    private _h = _id;
    [_h] spawn {
        params ["_x"];
        for "_i" from 0 to 4 do {
            stopSound _x;
            sleep 0.04;
        };
    };
};

FADE_civCarRadio_fnc_resolveVehicle = {
    params ["_sourceKey"];
    if (_sourceKey find "vehicle:" != 0) exitWith { objNull };
    private _nid = _sourceKey select [8];
    if (_nid == "") exitWith { objNull };
    objectFromNetId _nid
};

FADE_civCarRadio_fnc_clear = {
    params ["_sourceKey"];
    private _veh = [_sourceKey] call FADE_civCarRadio_fnc_resolveVehicle;
    if (!isNull _veh) then {
        private _snd = _veh getVariable ["FADE_civCarRadioSnd", objNull];
        if (!isNull _snd) then { deleteVehicle _snd };
        _veh setVariable ["FADE_civCarRadioSnd", nil, false];
    };
    private _list = missionNamespace getVariable ["FADE_civCarRadio_audio", []];
    private _keep = [];
    {
        _x params ["_k", "_ps3d", "_o"];
        if (_k == _sourceKey) then {
            [_ps3d] call FADE_civCarRadio_fnc_stopPs3d;
            if (!isNull _o) then { deleteVehicle _o };
        } else {
            _keep pushBack _x;
        };
    } forEach _list;
    missionNamespace setVariable ["FADE_civCarRadio_audio", _keep];
};

FADE_civCarRadio_fnc_tryPlaySound3D = {
    params ["_sourceKey", "_song", "_veh", "_vol", "_dist"];
    if (_song == "" || { isNull _veh }) exitWith { false };
    ([_song] call FADE_civCarRadio_fnc_oggFromSfx) params ["_file", "_pitch"];
    if (_file == "") exitWith { false };
    private _h = playSound3D [_file, _veh, false, getPosASL _veh, _vol, _pitch, _dist];
    if (isNil "_h" || { _h isEqualTo "" } || { !(_h isEqualType 0) } || { _h < 0 }) exitWith { false };
    private _list = missionNamespace getVariable ["FADE_civCarRadio_audio", []];
    _list = _list select { (_x select 0) != _sourceKey };
    _list pushBack [_sourceKey, _h, objNull];
    missionNamespace setVariable ["FADE_civCarRadio_audio", _list];
    true
};

FADE_civCarRadio_fnc_trySoundSource = {
    params ["_sourceKey", "_song", "_veh"];
    if (_song == "" || { isNull _veh }) exitWith { false };
    private _candidates = [format ["%1_Z", _song], _song];
    private _snd = objNull;
    for "_i" from 0 to (count _candidates - 1) do {
        if (!isNull _snd) exitWith {};
        private _cls = _candidates select _i;
        if (isClass (configFile >> "CfgVehicles" >> _cls)) then {
            private _try = createSoundSource [_cls, getPosATL _veh, [], 0];
            if (!isNull _try) then { _snd = _try };
        };
    };
    if (isNull _snd) exitWith { false };
    _snd attachTo [_veh, [0, 0, 0]];
    _veh setVariable ["FADE_civCarRadioSnd", _snd, false];
    private _list = missionNamespace getVariable ["FADE_civCarRadio_audio", []];
    _list = _list select { (_x select 0) != _sourceKey };
    _list pushBack [_sourceKey, "", _snd];
    missionNamespace setVariable ["FADE_civCarRadio_audio", _list];
    true
};

FADE_civCarRadio_clientPlay = {
    if (!hasInterface) exitWith {};
    params [["_song", ""], ["_sourceKey", ""], ["_vol", 25], ["_dist", 1000]];
    if (_sourceKey find "vehicle:" != 0) exitWith {};
    [_sourceKey] call FADE_civCarRadio_fnc_clear;
    if (_song == "") exitWith {};
    private _veh = [_sourceKey] call FADE_civCarRadio_fnc_resolveVehicle;
    if (isNull _veh) exitWith {};
    _vol = ((round _vol) max 1) min 25;
    _dist = ((round _dist) max 50) min 2500;
    if ([_sourceKey, _song, _veh, _vol, _dist] call FADE_civCarRadio_fnc_tryPlaySound3D) exitWith {};
    [_sourceKey, _song, _veh] call FADE_civCarRadio_fnc_trySoundSource;
};

FADE_civCarRadio_serverPlay = {
    if (!isServer) exitWith {};
    params [["_song", ""], ["_sourceKey", ""], ["_vol", 25], ["_dist", 1000]];
    if (_sourceKey find "vehicle:" != 0) exitWith {
        diag_log format ["FADE_civCarRadio_serverPlay: ignored key %1", _sourceKey];
    };
    if (_song == "") exitWith {
        ["", _sourceKey] remoteExec ["FADE_civCarRadio_clientPlay", 0];
    };
    private _veh = [_sourceKey] call FADE_civCarRadio_fnc_resolveVehicle;
    if (isNull _veh || {!alive _veh}) exitWith {
        diag_log format ["FADE_civCarRadio_serverPlay: no vehicle for %1", _sourceKey];
    };
    private _sndOk = isClass (configFile >> "CfgSFX" >> _song)
        || { isClass (configFile >> "CfgSounds" >> _song) };
    if (!_sndOk) exitWith {
        diag_log format ["FADE_civCarRadio_serverPlay: sound def %1 not in configFile CfgSFX/CfgSounds", _song];
    };
    _vol = ((round _vol) max 1) min 25;
    _dist = ((round _dist) max 50) min 2500;
    [_song, _sourceKey, _vol, _dist] remoteExec ["FADE_civCarRadio_clientPlay", 0];
    [_veh, _sourceKey] spawn {
        params ["_v", "_key"];
        waitUntil { sleep 1; isNull _v || {!alive _v} };
        if (isNull _v || {!alive _v}) then {
            ["", _key] remoteExec ["FADE_civCarRadio_clientPlay", 0];
        };
    };
};

missionNamespace setVariable ["FADE_civCarRadio_clientPlay", FADE_civCarRadio_clientPlay];
missionNamespace setVariable ["FADE_civCarRadio_serverPlay", FADE_civCarRadio_serverPlay];
if (isServer) then {
    publicVariable "FADE_civCarRadio_serverPlay";
    publicVariable "FADE_civCarRadio_clientPlay";
};
missionNamespace setVariable ["FADE_civCarRadio_installed", true];
