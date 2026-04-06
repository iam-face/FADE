// CTB Locker Room - client only (initPlayerLocal). Dedicated server does not run this; each human client runs one loop (not 30× on the server).
// Hostage + slap: independent timers (Config: default 3–6s).
// Perf: distanceSqr vs precomputed r² (no sqrt); adaptive sleep when far; nearestObjects only if no posLocker_* (prefer Eden helpers).
// MP: [player, [class, dist, pitch, 2]] remoteExec ["say3D", 0] so all clients hear 3D audio.
if (!hasInterface) exitWith {};

waitUntil { sleep 0.5; !isNull player && { alive player } };

private _dlyMin = missionNamespace getVariable ["FADE_lockerSoundDelayMin", 3];
private _dlyRand = missionNamespace getVariable ["FADE_lockerSoundDelayRand", 3];
private _fNextAt = { time + _dlyMin + random _dlyRand };

private _roomVar = missionNamespace getVariable ["FADE_lockerRoomCenterVar", "posLockerRoom"];
waitUntil { sleep 0.5; !isNull (missionNamespace getVariable [_roomVar, objNull]) };
private _roomCenter = missionNamespace getVariable _roomVar;

private _roomR = missionNamespace getVariable ["FADE_lockerRoomRadius", 20];
private _lockerD = missionNamespace getVariable ["FADE_lockerNearLockerDist", 5];
private _roomRSq = _roomR * _roomR;
private _lockerDSq = _lockerD * _lockerD;
private _sleepFarSq = (_roomR + 100) * (_roomR + 100);
private _sleepNearSq = (_roomR + 30) * (_roomR + 30);
private _lockerMax = missionNamespace getVariable ["FADE_lockerPosVarMax", 64];
private _hostageChance = missionNamespace getVariable ["FADE_lockerHostageChance", 1];
private _sndMax = 250;
private _emit3d = { [player, [_this, _sndMax, 1, 2]] remoteExec ["say3D", 0] };

// Eden helpers: documented as posLocker_0..N; this mission uses posLockers_1..N (extra "s", 1-based).
private _lockerObjs = [];
private _i = 0;
while { _i <= _lockerMax } do {
    private _o = missionNamespace getVariable [format ["posLocker_%1", _i], objNull];
    if (!isNull _o) then { _lockerObjs pushBack _o };
    _i = _i + 1;
};
private _j = 1;
while { _j <= _lockerMax } do {
    private _o2 = missionNamespace getVariable [format ["posLockers_%1", _j], objNull];
    if (!isNull _o2) then { _lockerObjs pushBack _o2 };
    _j = _j + 1;
};
private _hasHelpers = count _lockerObjs > 0;

private _hostage = [
    "FAC_hostage_interrupt_1", "FAC_hostage_interrupt_2", "FAC_hostage_interrupt_3",
    "FAC_hostage_pain_1", "FAC_hostage_pain_2", "FAC_hostage_pain_3",
    "FAC_hostage_pickup_1", "FAC_hostage_pickup_2", "FAC_hostage_pickup_3",
    "FAC_hostage_rescued_1", "FAC_hostage_rescued_2", "FAC_hostage_rescued_3",
    "FAC_hostage_struggle_1", "FAC_hostage_struggle_2", "FAC_hostage_struggle_3"
];
private _slap = [
    "FAC_sig_lockerslap_001", "FAC_sig_lockerslap_002", "FAC_sig_lockerslap_003"
];

private _nextHostage = 0;
private _nextSlap = 0;
private _wasInRoom = false;

while { alive player } do {
    if (isNull player || {!alive player}) exitWith {};

    private _distSq = player distanceSqr _roomCenter;
    private _inRoom = _distSq <= _roomRSq;

    private _nearLocker = false;
    if (_inRoom) then {
        if (_hasHelpers) then {
            _nearLocker = (_lockerObjs findIf { (player distanceSqr _x) <= _lockerDSq }) >= 0;
        } else {
            _nearLocker = count (nearestObjects [player, ["Metal_Locker_F"], _lockerD]) > 0;
        };
    };

    if (!_inRoom) then {
        _nextHostage = 0;
        _nextSlap = 0;
    } else {
        // Crossing into the room after being outside: clear schedule so hostage/slap timers arm again
        if (!_wasInRoom) then {
            _nextHostage = 0;
            _nextSlap = 0;
        };
        if (_nextHostage <= 0) then {
            _nextHostage = call _fNextAt;
        };
        if (time >= _nextHostage) then {
            if (random 1 < _hostageChance) then {
                (selectRandom _hostage) call _emit3d;
            };
            _nextHostage = call _fNextAt;
        };

        if (_nearLocker) then {
            if (_nextSlap <= 0) then {
                _nextSlap = call _fNextAt;
            };
            if (time >= _nextSlap) then {
                (selectRandom _slap) call _emit3d;
                _nextSlap = call _fNextAt;
            };
        } else {
            _nextSlap = 0;
        };
    };

    _wasInRoom = _inRoom;

    private _sleepT = 1;
    if (!_inRoom) then {
        if (_distSq > _sleepFarSq) then {
            _sleepT = 5;
        } else {
            if (_distSq > _sleepNearSq) then {
                _sleepT = 2;
            };
        };
    };
    sleep _sleepT;
};
