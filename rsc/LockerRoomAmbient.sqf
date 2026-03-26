// CTB Locker Room — client only (initPlayerLocal). Hostage + slap: independent timers (Config: default 3–6s).
// Perf: adaptive sleep when far from room; nearestObjects only when no posLocker_* helpers.
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
private _lockerMax = missionNamespace getVariable ["FADE_lockerPosVarMax", 64];
private _hostageChance = missionNamespace getVariable ["FADE_lockerHostageChance", 1];
private _sndMax = 250;
private _emit3d = { [player, [_this, _sndMax, 1, 2]] remoteExec ["say3D", 0] };

private _lockerObjs = [];
private _i = 0;
while { _i <= _lockerMax } do {
    private _o = missionNamespace getVariable [format ["posLocker_%1", _i], objNull];
    if (!isNull _o) then { _lockerObjs pushBack _o };
    _i = _i + 1;
};
private _hasHelpers = count _lockerObjs > 0;

private _hostage = [
    "FAC_hostage_interrupt_1", "FAC_hostage_interrupt_2", "FAC_hostage_interrupt_3", "FAC_hostage_interrupt_4",
    "FAC_hostage_interrupt_5", "FAC_hostage_interrupt_6", "FAC_hostage_interrupt_7",
    "FAC_hostage_pain_1", "FAC_hostage_pain_2", "FAC_hostage_pain_3", "FAC_hostage_pain_4", "FAC_hostage_pain_5",
    "FAC_hostage_pain_6", "FAC_hostage_pain_7", "FAC_hostage_pain_8", "FAC_hostage_pain_9", "FAC_hostage_pain_10",
    "FAC_hostage_pain_11", "FAC_hostage_pain_12", "FAC_hostage_pain_13",
    "FAC_hostage_pickup_1", "FAC_hostage_pickup_2", "FAC_hostage_pickup_3", "FAC_hostage_pickup_4", "FAC_hostage_pickup_5",
    "FAC_hostage_pickup_6", "FAC_hostage_pickup_7", "FAC_hostage_pickup_8", "FAC_hostage_pickup_9", "FAC_hostage_pickup_10",
    "FAC_hostage_pickup_11", "FAC_hostage_pickup_12", "FAC_hostage_pickup_13",
    "FAC_hostage_rescued_1", "FAC_hostage_rescued_2", "FAC_hostage_rescued_3", "FAC_hostage_rescued_4", "FAC_hostage_rescued_5",
    "FAC_hostage_struggle_1", "FAC_hostage_struggle_2", "FAC_hostage_struggle_3", "FAC_hostage_struggle_4", "FAC_hostage_struggle_5",
    "FAC_hostage_struggle_6", "FAC_hostage_struggle_7", "FAC_hostage_struggle_8", "FAC_hostage_struggle_9", "FAC_hostage_struggle_10",
    "FAC_hostage_struggle_11", "FAC_hostage_struggle_12", "FAC_hostage_struggle_13", "FAC_hostage_struggle_14", "FAC_hostage_struggle_15"
];
private _slap = [
    "FAC_sig_lockerslap_001", "FAC_sig_lockerslap_002", "FAC_sig_lockerslap_003", "FAC_sig_lockerslap_004", "FAC_sig_lockerslap_005",
    "FAC_sig_lockerslap_006", "FAC_sig_lockerslap_007", "FAC_sig_lockerslap_008", "FAC_sig_lockerslap_009"
];

private _nextHostage = 0;
private _nextSlap = 0;

while { alive player } do {
    if (isNull player || {!alive player}) exitWith {};

    private _dist = player distance _roomCenter;
    private _inRoom = _dist <= _roomR;

    private _nearLocker = false;
    if (_inRoom) then {
        if (_hasHelpers) then {
            _nearLocker = (_lockerObjs findIf { (player distance _x) <= _lockerD }) >= 0;
        } else {
            _nearLocker = count (nearestObjects [player, ["Metal_Locker_F"], _lockerD]) > 0;
        };
    };

    if (!_inRoom) then {
        _nextHostage = 0;
        _nextSlap = 0;
    } else {
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

    private _sleepT = 1;
    if (!_inRoom) then {
        if (_dist > _roomR + 100) then {
            _sleepT = 5;
        } else {
            if (_dist > _roomR + 30) then {
                _sleepT = 2;
            };
        };
    };
    sleep _sleepT;
};
