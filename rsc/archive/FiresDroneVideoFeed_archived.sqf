// =============================================================================
// ARCHIVED — NOT loaded by the mission (reference / restore only)
// =============================================================================
// Full drone briefing-screen RTT stack removed from rsc/FiresFallOfShot.sqf.
// Depends on: FAC_FiresFoS_fnc_resolveEdenNamedObject, FAC_firesFoS_fnc_rttProceduralTex,
// FAC_firesFoS_fnc_applyRttGlobal, FAC_firesFoS_fnc_clearRttGlobal (still in main file).
// Eden: droneVideoScreen. Config (removed from Config.sqf): FADE_firesDroneVideoTextureIndices,
// FADE_firesDroneVideoRttResolution, FADE_firesDroneRttFrameSkip, FADE_firesDroneRttCullDistanceM,
// FADE_firesDroneRttFrameSkipFar.
// =============================================================================

#define FAC_FiresFoS_DRONE_RTT "FAC_FiresDroneRTT"

// Server — was publicVariable'd as FADE_firesFoS_droneRttResetRequest in initServer.sqf
FADE_firesFoS_droneRttResetRequest_ARCHIVED = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    private _nid = missionNamespace getVariable ["FAC_firesFoS_rangeDroneNetId", ""];
    private _drone = if (_nid != "") then { [_nid] call FAC_firesFoS_server_objFromNetId } else { objNull };
    if (_nid == "" || {isNull _drone}) then {
        [] remoteExec ["FAC_firesFoS_fnc_reDroneStop", 0];
        if (!isNull _player) then {
            ["FIRES: UAV screen feed cleared (no active observer drone)."] remoteExec ["systemChat", _player];
        };
    } else {
        [_nid] remoteExec ["FAC_firesFoS_fnc_reDroneSync", 0];
        if (!isNull _player) then {
            ["FIRES: UAV briefing-screen feed restarted for all clients."] remoteExec ["systemChat", _player];
        };
    };
};

FAC_firesFoS_fnc_textureIndicesDrone_ARCHIVED = {
    private _a = missionNamespace getVariable ["FADE_firesDroneVideoTextureIndices", [0]];
    if !(_a isEqualType []) then { _a = [0] };
    if (count _a == 0) then { _a = [0] };
    _a
};

FAC_firesFoS_fnc_stopDroneRtt_ARCHIVED = {
    uiNamespace setVariable ["FAC_firesFoS_droneRttUseGunnerMem", false];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelA", nil];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelB", nil];
    private _cam = uiNamespace getVariable ["FAC_firesFoS_droneCam", objNull];
    if (!isNull _cam) then {
        _cam camCommit 0;
        _cam cameraEffect ["terminate", "back"];
        camDestroy _cam;
    };
    uiNamespace setVariable ["FAC_firesFoS_droneCam", nil];
    private _eh = uiNamespace getVariable ["FAC_firesFoS_droneFrameEh", -1];
    if (_eh >= 0) then {
        removeMissionEventHandler ["EachFrame", _eh];
    };
    uiNamespace setVariable ["FAC_firesFoS_droneFrameEh", -1];
    uiNamespace setVariable ["FAC_firesFoS_droneFrameCtr", 0];
    private _scr = missionNamespace getVariable ["FAC_firesFoS_droneScreenObj", objNull];
    if (!isNull _scr) then {
        [_scr, [] call FAC_firesFoS_fnc_textureIndicesDrone_ARCHIVED] call FAC_firesFoS_fnc_clearRttGlobal;
    };
    missionNamespace setVariable ["FAC_firesFoS_droneScreenObj", nil];
    uiNamespace setVariable ["FAC_firesFoS_droneVeh", nil];
};

FAC_firesFoS_fnc_droneRttDirToUp_ARCHIVED = {
    params [["_dir", [0, 0, 0]]];
    private _right = _dir vectorCrossProduct [0, 0, 1];
    if ((vectorMagnitude _right) < 0.001) then { _right = _dir vectorCrossProduct [0, 1, 0] };
    _right = vectorNormalized _right;
    vectorNormalized (_right vectorCrossProduct _dir)
};

FAC_firesFoS_fnc_droneRttPickPilotCamAsl_ARCHIVED = {
    params [["_d", objNull], ["_dAsl", [0, 0, 0]], ["_dz", 0]];
    if (isNull _d || {!hasPilotCamera _d}) exitWith { [] };
    private _raw = getPilotCameraPosition _d;
    if (!(_raw isEqualType []) || {count _raw < 3}) exitWith { [] };
    private _cands = [_raw];
    private _mw = AGLtoASL (_d modelToWorld _raw);
    if (_mw isEqualType [] && {count _mw >= 3}) then { _cands pushBack _mw };
    private _best = [];
    private _bestD = 1e12;
    {
        private _p = _x;
        if (count _p >= 3) then {
            private _dist = _dAsl vectorDistance _p;
            private _th = getTerrainHeightASL [_p select 0, _p select 1];
            if (
                _dist < 400 &&
                {_dist > 0.05} &&
                {(_p select 2) > (_th - 50)} &&
                {(_p select 2) > -5} &&
                {(_p select 2) < (_dz + 150)} &&
                {_dist < _bestD}
            ) then {
                _bestD = _dist;
                _best = _p;
            };
        };
    } forEach _cands;
    _best
};

FAC_firesFoS_fnc_droneRttReadGunnerMemPoints_ARCHIVED = {
    params [["_veh", objNull]];
    if (isNull _veh) exitWith { ["", ""] };
    private _cfg = configFile >> "CfgVehicles" >> typeOf _veh;
    if (!isClass _cfg) exitWith { ["", ""] };
    private _p = getText (_cfg >> "uavCameraGunnerPos");
    private _q = getText (_cfg >> "uavCameraGunnerDir");
    if (_p == "" || {_q == ""}) exitWith { ["", ""] };
    [_p, _q]
};

FAC_firesFoS_fnc_droneRttApplyFrame_ARCHIVED = {
    params [["_c", objNull], ["_d", objNull]];
    if (isNull _c || {isNull _d}) exitWith {};
    if (uiNamespace getVariable ["FAC_firesFoS_droneRttUseGunnerMem", false]) then {
        private _gPos = uiNamespace getVariable ["FAC_firesFoS_droneGunnerSelA", ""];
        private _gDir = uiNamespace getVariable ["FAC_firesFoS_droneGunnerSelB", ""];
        if (_gPos != "" && {_gDir != ""}) then {
            private _dir = (_d selectionPosition _gPos) vectorFromTo (_d selectionPosition _gDir);
            if ((vectorMagnitude _dir) > 1e-4) then {
                _dir = vectorNormalized _dir;
                private _up = _dir vectorCrossProduct [-(_dir select 1), _dir select 0, 0];
                _c setVectorDirAndUp [_dir, _up];
                _c camSetFov 0.55;
                _c camCommit 0;
            };
        };
    } else {
        private _gn = gunner _d;
        if (!isNull _gn && {alive _gn}) then {
            private _dAslG = getPosASL _d;
            private _dzG = _dAslG select 2;
            private _eyeG = eyePos _gn;
            private _ppG = [_d, _dAslG, _dzG] call FAC_firesFoS_fnc_droneRttPickPilotCamAsl_ARCHIVED;
            private _nearG = (count _ppG >= 3) && {(_eyeG vectorDistance _ppG) < 25};
            private _pos = if (_nearG) then { _ppG } else { _eyeG };
            private _pdG = if (hasPilotCamera _d) then { getPilotCameraDirection _d } else { [] };
            if (_pdG isEqualType [] && {count _pdG >= 3} && {(vectorMagnitude _pdG) > 0.01}) then {
                private _dU = vectorNormalized _pdG;
                _c setPosASL _pos;
                _c setVectorDirAndUp [_dU, [_dU] call FAC_firesFoS_fnc_droneRttDirToUp_ARCHIVED];
            } else {
                _c setPosASL _pos;
                _c setVectorDirAndUp [vectorDir _gn, vectorUp _gn];
            };
            _c camSetFov 0.55;
            _c camCommit 0;
        } else {
            private _dAsl = getPosASL _d;
            private _dz = _dAsl select 2;
            private _pd = if (hasPilotCamera _d) then { getPilotCameraDirection _d } else { [] };
            private _dirOk = (_pd isEqualType [] && {count _pd >= 3} && {(vectorMagnitude _pd) > 0.01});
            private _pp = [_d, _dAsl, _dz] call FAC_firesFoS_fnc_droneRttPickPilotCamAsl_ARCHIVED;
            private _pcPosOk = (count _pp >= 3);
            private _drv0 = driver _d;
            private _base = if (!isNull _drv0 && {alive _drv0}) then {
                eyePos _drv0
            } else {
                _dAsl vectorAdd (_d vectorModelToWorld [0, 0, -0.25])
            };
            if (_pcPosOk && _dirOk) then {
                private _dV = vectorNormalized _pd;
                _c setPosASL _pp;
                _c setVectorDirAndUp [_dV, [_dV] call FAC_firesFoS_fnc_droneRttDirToUp_ARCHIVED];
            } else {
                if (_dirOk) then {
                    private _dV = vectorNormalized _pd;
                    _c setPosASL _base;
                    _c setVectorDirAndUp [_dV, [_dV] call FAC_firesFoS_fnc_droneRttDirToUp_ARCHIVED];
                } else {
                    if (!isNull _drv0 && {alive _drv0}) then {
                        _c setPosASL _base;
                        _c setVectorDirAndUp [vectorDir _drv0, vectorUp _drv0];
                    } else {
                        _c setPosASL _base;
                        _c setVectorDirAndUp [vectorDir _d, vectorUp _d];
                    };
                };
            };
            _c camSetFov 0.55;
            _c camCommit 0;
        };
    };
};

// Original clientDroneSync: bind r2t to droneVideoScreen + EachFrame camera follow
FAC_firesFoS_fnc_clientDroneSync_ARCHIVED = {
    params [["_nid", ""]];
    if (_nid == "") exitWith { [] call FAC_firesFoS_fnc_stopDroneRtt_ARCHIVED };

    private _drone = objNull;
    if (_nid != "") then {
        _drone = objectFromNetId _nid;
        if (isNull _drone) then {
            { if (netId _x == _nid) exitWith { _drone = _x } } forEach vehicles;
        };
    };
    if (isNull _drone) exitWith { [] call FAC_firesFoS_fnc_stopDroneRtt_ARCHIVED };

    [] call FAC_firesFoS_fnc_stopDroneRtt_ARCHIVED;

    private _screen = ["droneVideoScreen"] call FAC_firesFoS_fnc_resolveEdenNamedObject;
    if (isNull _screen) exitWith {};

    missionNamespace setVariable ["FAC_firesFoS_droneScreenObj", _screen];
    uiNamespace setVariable ["FAC_firesFoS_droneVeh", _drone];

    private _res = round (missionNamespace getVariable ["FADE_firesDroneVideoRttResolution", 512]);
    if (_res < 128) then { _res = 512 };
    private _tex = [_res, FAC_FiresFoS_DRONE_RTT] call FAC_firesFoS_fnc_rttProceduralTex;
    [_screen, _tex, [] call FAC_firesFoS_fnc_textureIndicesDrone_ARCHIVED] call FAC_firesFoS_fnc_applyRttGlobal;

    private _cam = "camera" camCreate [0, 0, 0];
    _cam cameraEffect ["Internal", "Back", FAC_FiresFoS_DRONE_RTT];
    uiNamespace setVariable ["FAC_firesFoS_droneCam", _cam];

    uiNamespace setVariable ["FAC_firesFoS_droneRttUseGunnerMem", false];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelA", nil];
    uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelB", nil];
    ([_drone] call FAC_firesFoS_fnc_droneRttReadGunnerMemPoints_ARCHIVED) params ["_memPos", "_memDir"];
    if (_memPos != "" && {_memDir != ""}) then {
        private _t = (_drone selectionPosition _memPos) vectorFromTo (_drone selectionPosition _memDir);
        if ((vectorMagnitude _t) > 1e-4) then {
            _cam attachTo [_drone, [0, 0, 0], _memPos];
            uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelA", _memPos];
            uiNamespace setVariable ["FAC_firesFoS_droneGunnerSelB", _memDir];
            uiNamespace setVariable ["FAC_firesFoS_droneRttUseGunnerMem", true];
        };
    };

    [_cam, _drone] call FAC_firesFoS_fnc_droneRttApplyFrame_ARCHIVED;
    uiNamespace setVariable ["FAC_firesFoS_droneFrameCtr", 0];

    private _eh = addMissionEventHandler ["EachFrame", {
        private _c = uiNamespace getVariable ["FAC_firesFoS_droneCam", objNull];
        private _nn = missionNamespace getVariable ["FAC_firesFoS_rangeDroneNetId", ""];
        private _d = uiNamespace getVariable ["FAC_firesFoS_droneVeh", objNull];
        if (!isNull _d && {!alive _d}) then {
            _d = objNull;
            uiNamespace setVariable ["FAC_firesFoS_droneVeh", nil];
        };
        if (!isNull _d && {_nn != ""} && {netId _d != _nn}) then { _d = objNull };
        if (isNull _d && {_nn != ""}) then {
            _d = objectFromNetId _nn;
            if (isNull _d) then {
                { if (netId _x == _nn) exitWith { _d = _x } } forEach vehicles;
            };
            if (!isNull _d) then { uiNamespace setVariable ["FAC_firesFoS_droneVeh", _d] };
        };
        if (isNull _c || {isNull _d}) exitWith {};

        private _skipB = (missionNamespace getVariable ["FADE_firesDroneRttFrameSkip", 2]) max 1;
        private _skip = _skipB;
        private _cullD = missionNamespace getVariable ["FADE_firesDroneRttCullDistanceM", 450];
        if (_cullD > 0) then {
            private _scr = missionNamespace getVariable ["FAC_firesFoS_droneScreenObj", objNull];
            if (!isNull _scr && {(player distance _scr) > _cullD}) then {
                _skip = ((missionNamespace getVariable ["FADE_firesDroneRttFrameSkipFar", 4]) max _skipB);
            };
        };

        private _ctr = uiNamespace getVariable ["FAC_firesFoS_droneFrameCtr", 0];
        _ctr = _ctr + 1;
        if (_ctr >= _skip) then {
            uiNamespace setVariable ["FAC_firesFoS_droneFrameCtr", 0];
            [_c, _d] call FAC_firesFoS_fnc_droneRttApplyFrame_ARCHIVED;
        } else {
            uiNamespace setVariable ["FAC_firesFoS_droneFrameCtr", _ctr];
        };
    }];
    uiNamespace setVariable ["FAC_firesFoS_droneFrameEh", _eh];
};
