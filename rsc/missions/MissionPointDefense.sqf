// Point Defense — hold a 250 m zone against INF / VEH+INF waves for a set duration.
if (!isServer) exitWith {};

FADE_pd_findAdjacentCivZonePos = {
    params ["_center", "_minDist"];
    private _best = [];
    private _bestD = 1e12;
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            private _d = _p distance2D _center;
            if (_d >= _minDist && { _d < _bestD }) then {
                _bestD = _d;
                _best = +_p;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _best
};

FADE_pd_pickInfSpawnPos = {
    params ["_center", "_zoneRadius", "_minRing", "_maxRing"];
    private _sp = [];
    for "_try" from 1 to 12 do {
        private _dist = _minRing + random ((_maxRing - _minRing) max 1);
        private _cand = _center getPos [_dist, random 360];
        _cand = [[_cand, 0, 40, 3, 1, 0.4, 0, [], _cand], _cand] call FADE_findSafePosArray;
        if (_cand isEqualType [] && { count _cand >= 2 } && { (_cand distance2D _center) > (_zoneRadius + 40) }) exitWith {
            if (count _cand < 3) then { _cand = [(_cand select 0), (_cand select 1), 0] };
            _sp = _cand;
        };
    };
    if (_sp isEqualTo []) then {
        _sp = _center getPos [(_minRing + _maxRing) * 0.5, random 360];
        if (count _sp < 3) then { _sp set [2, 0] };
    };
    _sp
};

FADE_pd_spawnFlavourWreck = {
    params ["_center", "_taskId"];
    private _wreckData = [_center, _taskId] call FADE_mission_spawnCasualtyHeliWreck;
    _wreckData params [["_wreck", objNull], "", ["_crashPos", []], ""];
    private _objs = [];
    if (!isNull _wreck) then { _objs pushBack _wreck };
    ["wreck", _objs, [], if (count _crashPos >= 2) then { _crashPos } else { _center }]
};

FADE_pd_spawnFlavourConvoy = {
    params ["_center", "_taskId", "_sideFriendly", "_friendlyUnits", "_zoneRadius"];
    private _objs = [];
    private _groups = [];
    private _land = (missionNamespace getVariable ["FADE_friendlyVehicleClasses", []]) select {
        _x isKindOf "LandVehicle"
        && { !(_x isKindOf "Air") }
        && { !(_x isKindOf "Ship") }
        && { !(_x isKindOf "StaticWeapon") }
        && { getNumber (configFile >> "CfgVehicles" >> _x >> "isUav") < 1 }
    };
    if (_land isEqualTo []) then {
        _land = (missionNamespace getVariable ["FADE_landVehicleClasses", []]) select {
            _x isKindOf "LandVehicle" && { !(_x isKindOf "Air") } && { !(_x isKindOf "Ship") }
        };
    };
    private _roadHit = [];
    private _roadFn = missionNamespace getVariable ["FADE_findOpforGroundVehicleRoadSpawn", {}];
    if (!(_roadFn isEqualTo {})) then {
        _roadHit = [_center, (_zoneRadius max 80) min 220, [], -1, [], _center] call _roadFn;
    };
    private _roadSp = _center;
    private _vehDir = random 360;
    if (!(_roadHit isEqualTo []) && { count _roadHit >= 2 }) then {
        _roadHit params ["_rs", "_rd"];
        _roadSp = _rs;
        _vehDir = _rd;
    } else {
        private _roads = _center nearRoads ((_zoneRadius max 80) min 250);
        if (count _roads > 0) then {
            private _rd = selectRandom _roads;
            _roadSp = getPosATL _rd;
            private _conn = roadsConnectedTo _rd;
            if (count _conn > 0) then { _vehDir = _roadSp getDir (getPosATL (_conn select 0)) };
        };
    };
    private _count = 2 + floor random 2;
    private _existing = [];
    for "_i" from 0 to (_count - 1) do {
        if (count _land == 0) exitWith {};
        private _cls = selectRandom _land;
        private _offset = _roadSp getPos [8 * _i, _vehDir + 180];
        private _veh = createVehicle [_cls, _offset, [], 0, "NONE"];
        if (isNull _veh) then { continue };
        _veh setPosATL _offset;
        _veh setDir _vehDir;
        _veh setVectorUp surfaceNormal _offset;
        _veh setFuel 0.15;
        _veh engineOn false;
        [_taskId, _veh] call FADE_missionEnt_registerObject;
        _objs pushBack _veh;
        _existing pushBack _veh;
        if (count _friendlyUnits > 0) then {
            private _crewGrp = createGroup _sideFriendly;
            private _driver = _crewGrp createUnit [selectRandom _friendlyUnits, _offset, [], 0, "NONE"];
            if (!isNull _driver) then {
                _driver moveInDriver _veh;
                _crewGrp selectLeader _driver;
            };
            if (_veh emptyPositions "gunner" > 0) then {
                private _g = _crewGrp createUnit [selectRandom _friendlyUnits, _offset, [], 0, "NONE"];
                if (!isNull _g) then { _g moveInGunner _veh };
            };
            if (!isNull _crewGrp && { count units _crewGrp > 0 }) then {
                _crewGrp setBehaviour "COMBAT";
                _crewGrp setCombatMode "YELLOW";
                [_taskId, _crewGrp] call FADE_missionEnt_registerGroup;
                _groups pushBack _crewGrp;
            };
        };
    };
    if (count _friendlyUnits > 0) then {
        private _infN = 4 + floor random 3;
        private _classes = [];
        private _shuf = _friendlyUnits call BIS_fnc_arrayShuffle;
        for "_i" from 0 to (_infN - 1) do {
            _classes pushBack (_shuf select (_i min ((count _shuf) - 1)));
        };
        private _infPos = _roadSp getPos [12, _vehDir + 90];
        _infPos = [[_infPos, 0, 20, 2, 1, 0.4, 0, [], _infPos], _infPos] call FADE_findSafePosArray;
        if (!(_infPos isEqualType []) || { count _infPos < 2 }) then { _infPos = _roadSp };
        private _infGrp = [_infPos, _sideFriendly, _classes] call FADE_spawnFriendlyInfantryGroupAt;
        if (!isNull _infGrp) then {
            _infGrp setBehaviour "COMBAT";
            _infGrp setCombatMode "YELLOW";
            [_taskId, _infGrp] call FADE_missionEnt_registerGroup;
            _groups pushBack _infGrp;
        };
    };
    ["convoy", _objs, _groups, _roadSp]
};

FADE_pd_countWaveAlive = {
    params ["_units"];
    { alive _x } count _units
};

FADE_pd_spawnInfWave = {
    params ["_taskId", "_center", "_zoneRadius", "_enemyUnits", "_sideEnemy", "_scaleOpforCount", "_waveIdx"];
    private _minRing = missionNamespace getVariable ["FADE_pointDefenseInfSpawnMinM", 350];
    private _maxRing = missionNamespace getVariable ["FADE_pointDefenseInfSpawnMaxM", 500];
    private _sp = [_center, _zoneRadius, _minRing, _maxRing] call FADE_pd_pickInfSpawnPos;
    private _baseSize = (4 + floor random 3) + (floor (_waveIdx / 2) min 3);
    private _ps = [_baseSize, 2] call _scaleOpforCount;
    private _shuf = _enemyUnits call BIS_fnc_arrayShuffle;
    private _classes = _shuf select [0, _ps min count _shuf];
    if (count _classes == 0) then { _classes = [_enemyUnits select 0] };
    private _grp = [_sp, _sideEnemy, _classes] call BIS_fnc_spawnGroup;
    if (isNull _grp || { count units _grp == 0 }) exitWith { [] };
    [_grp] call FAC_applyEnemyScenarioToGroup;
    [_grp, _center, _zoneRadius] call FADE_invasion_assignPushWp;
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    private _units = units _grp;
    { _x setVariable ["FADE_pdWaveUnit", true, false] } forEach _units;
    _units
};

FADE_pd_spawnVehWave = {
    params ["_taskId", "_center", "_zoneRadius", "_enemyUnits", "_sideEnemy", "_scaleOpforCount", "_waveIdx", "_existingVehs"];
    private _adj = [_center, _zoneRadius + 200] call FADE_pd_findAdjacentCivZonePos;
    if (_adj isEqualTo []) then {
        private _minRing = missionNamespace getVariable ["FADE_pointDefenseInfSpawnMinM", 350];
        private _maxRing = missionNamespace getVariable ["FADE_pointDefenseInfSpawnMaxM", 500];
        _adj = [_center, _zoneRadius, _minRing + 150, _maxRing + 350] call FADE_pd_pickInfSpawnPos;
    };
    private _pack = [_adj, _center, _enemyUnits, FAC_applyEnemyScenarioToGroup, _existingVehs, _zoneRadius] call FADE_invasion_makePushVeh;
    _pack params [["_veh", objNull], ["_vehGrp", grpNull], ["_cargoGrp", grpNull]];
    private _units = [];
    if (!isNull _veh) then {
        [_taskId, _veh] call FADE_missionEnt_registerObject;
        _existingVehs pushBack _veh;
    };
    if (!isNull _vehGrp) then {
        [_taskId, _vehGrp] call FADE_missionEnt_registerGroup;
        { _units pushBack _x; _x setVariable ["FADE_pdWaveUnit", true, false] } forEach (units _vehGrp);
    };
    if (!isNull _cargoGrp) then {
        [_taskId, _cargoGrp] call FADE_missionEnt_registerGroup;
        { _units pushBack _x; _x setVariable ["FADE_pdWaveUnit", true, false] } forEach (units _cargoGrp);
    };
    // Escalate with a second foot squad on later waves when the vehicle pack was thin
    if (_waveIdx >= 3 && { count _units < 6 }) then {
        private _extra = [_taskId, _center, _zoneRadius, _enemyUnits, _sideEnemy, _scaleOpforCount, _waveIdx] call FADE_pd_spawnInfWave;
        _units append _extra;
    };
    _units
};

FADE_runMission_PointDefense = {
    (call FADE_missionRun_getContext) params [
        "_missionType", "_destPos", "_player", "_evadeePlayers", "_fromMapClick", "_mapAnchor",
        "_friendlyUnits", "_enemyUnits", "_sideFriendly", "_sideEnemy", "_markerFriendly", "_markerEnemy",
        "_dryPos", "_taskId", "_operationName", "_operationNameUpper", "_briefGuiTail",
        "_mkrJitter", "_enemyFactionName", "_zeroAlphaDisplayName", "_isGlobalMission", "_basePos",
        "_unitCount", "_unitClasses", "_scaleOpforCount", "_fnc_createMissionTask", "_showAssignedHint",
        "_defaultSituationTaskText", "_defaultExecutionTaskText", "_defaultAdminTaskText", "_defaultCommandTaskText",
        "_defaultSituationHtml", "_defaultSituationHintHtml", "_friendlyPlayerCount", "_friendlyFactionName",
        "_estimatedOpforCount", "_opforCountFactor", "_intelFormatter", "_topographyGrid", "_topographyArea",
        "_mapPickRawAnchor", "_mapPickSnappedCenter", "_mapPickResolvedR", "_convoyEndRaw", "_convoyEndAnchor", "_raidZoneClicks",
        "_loreShort", "_loreLong", "_loreSmeacHtml"
    ];

    private _enemyUnitsPD = +_enemyUnits;
    _enemyUnitsPD = [_enemyUnitsPD] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsPD == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No enemy units configured."] call FADE_missionErrorHint;
    };

    private _center = +_destPos;
    if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
        _center = +_mapAnchor;
    };
    if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };

    private _zoneRadius = missionNamespace getVariable ["FADE_pointDefenseRadiusM", 250];
    private _durMin = missionNamespace getVariable ["FADE_pointDefenseDurationMinSec", 300];
    private _durMax = missionNamespace getVariable ["FADE_pointDefenseDurationMaxSec", 2400];
    private _durationSec = missionNamespace getVariable ["FADE_pdRun_durationSec", missionNamespace getVariable ["FADE_pointDefenseDurationSec", 1200]];
    if (!(_durationSec isEqualType 0)) then { _durationSec = 1200 };
    _durationSec = (round _durationSec max _durMin) min _durMax;
    missionNamespace setVariable ["FADE_pdRun_durationSec", nil];

    private _markerNames = [];
    [_taskId, "FADE_pd", 0, _center, _zoneRadius, _markerFriendly, "POINT DEFENSE", _mkrJitter, _markerNames] call FADE_zone_createCaptureMarkerPair;
    private _mArea = _markerNames param [0, ""];
    private _mIcon = _markerNames param [1, ""];
    if (_mArea != "") then { _player setVariable ["FADE_myMissionMarker", _mArea, true] };

    private _flavourKind = if (random 1 < 0.5) then { "wreck" } else { "convoy" };
    private _flavourObjs = [];
    private _flavourGroups = [];
    private _flavourAnchor = _center;
    if (_flavourKind == "wreck") then {
        private _pack = [_center, _taskId] call FADE_pd_spawnFlavourWreck;
        _pack params ["_kind", "_objs", "_grps", "_anchor"];
        _flavourKind = _kind;
        _flavourObjs = _objs;
        _flavourGroups = _grps;
        _flavourAnchor = _anchor;
    } else {
        private _pack = [_center, _taskId, _sideFriendly, _friendlyUnits, _zoneRadius] call FADE_pd_spawnFlavourConvoy;
        _pack params ["_kind", "_objs", "_grps", "_anchor"];
        _flavourKind = _kind;
        _flavourObjs = _objs;
        _flavourGroups = _grps;
        _flavourAnchor = _anchor;
        if (_flavourObjs isEqualTo []) then {
            private _fallback = [_center, _taskId] call FADE_pd_spawnFlavourWreck;
            _fallback params ["_k2", "_o2", "_g2", "_a2"];
            _flavourKind = _k2;
            _flavourObjs = _o2;
            _flavourGroups = _g2;
            _flavourAnchor = _a2;
        };
    };

    private _durMinLabel = floor (_durationSec / 60);
    private _whyLine = if (_flavourKind == "convoy") then {
        "A friendly convoy was forced to halt in the zone — hold until relief arrives."
    } else {
        "A friendly helicopter is down in the zone — hold the crash site until the window closes."
    };
    private _topoPd = [_center] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _grid = _topoPd param [0, mapGridPosition _center];
    private _areaName = _topoPd param [1, "Unknown area"];
    private _taskDesc = format [
        "Occupy and defend the marked 250 m point at Grid %1 (%2) for %3 minutes. Timer starts when players enter the zone. Mission fails immediately if enemy forces enter while no players are present. %4",
        _grid,
        _areaName,
        _durMinLabel,
        _whyLine
    ];
    private _execOverride = format [
        "<t align='left' color='#C0C0C0'>Enter the 250 m zone to start the %1-minute hold clock. %2 Expect infantry assaults from the near perimeter and vehicle-borne waves from adjacent settlements. Keep at least one player inside while enemies contest the point. Success: hold until the timer expires. Fail: enemy in zone with no players present.</t>",
        _durMinLabel,
        _whyLine
    ];
    // Refreshes SMEAC situation/lore at the defend site (same path as Clear Area / HVT / etc.).
    [_player, _taskId, _taskDesc, "Point Defense", _center, "defend", "", _execOverride] call _fnc_createMissionTask;

    private _hqBoardFn = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
    if (_hqBoardFn isEqualType {} && { !(_hqBoardFn isEqualTo {}) }) then { [_center] call _hqBoardFn };

    private _brief = format [
        "POINT DEFENSE%1%1Defend Grid %2 (%3) for %4 minutes once players enter the 250 m zone.%1%1%5%1%1Fail: enemy in zone with no players present. Success: hold until the timer expires.%1%1See Tasks for full SMEAC (situation, execution, admin, command).",
        toString [10],
        _grid,
        _areaName,
        _durMinLabel,
        _whyLine
    ] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];

    // Lore short/long + diary background (refreshed by createMissionTask at _center).
    [] call _showAssignedHint;
    [_player, "Point Defense"] call FADE_notifyOthersMissionStarted;

    missionNamespace setVariable ["FADE_pdAborted_" + _taskId, false];

    [
        _taskId, _player, _center, _zoneRadius, _durationSec, _enemyUnitsPD, _sideEnemy, _scaleOpforCount,
        _markerFriendly, _markerEnemy, _mArea, _mIcon, _flavourObjs, _flavourKind, _durMinLabel
    ] spawn {
        params [
            "_taskId", "_player", "_center", "_zoneRadius", "_durationSec", "_enemyUnits", "_sideEnemy", "_scaleOpforCount",
            "_markerFriendly", "_markerEnemy", "_mArea", "_mIcon", "_flavourObjs", "_flavourKind", "_durMinLabel"
        ];

        private _poll = missionNamespace getVariable ["FADE_pointDefensePollSec", 1];
        private _clearPct = missionNamespace getVariable ["FADE_pointDefenseWaveClearPct", 0.25];
        private _maxInterval = missionNamespace getVariable ["FADE_pointDefenseWaveMaxIntervalSec", 105];
        private _maxConcurrent = missionNamespace getVariable ["FADE_pointDefenseMaxConcurrent", 36];
        private _vehChance = missionNamespace getVariable ["FADE_pointDefenseVehWaveChance", 0.45];

        private _timerStarted = false;
        private _timerStart = 0;
        private _waveIdx = 0;
        private _waveUnits = [];
        private _waveSpawned = 0;
        private _lastWaveTime = 0;
        private _allWaveUnits = [];
        private _waveVehs = [];
        private _armedHintSent = false;

        private _fnc_finish = {
            params ["_state", "_msg"];
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith {};
            [_taskId, _state] call BIS_fnc_taskSetState;
            if (_msg != "" && { !isNull _player }) then {
                if (_state == "SUCCEEDED") then {
                    [_player, _msg] call FADE_missionSuccessHint;
                } else {
                    if (_state == "FAILED") then {
                        [_player, _msg] call FADE_missionFailHint;
                    } else {
                        [_player, "POINT DEFENSE", _msg, "#FFAA00"] call FADE_missionOutcomeHint;
                    };
                };
            };
        };

        waitUntil {
            sleep _poll;
            if (missionNamespace getVariable ["FADE_pdAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };

            private _pCnt = [_center, _zoneRadius] call FADE_op_countBluforPlayersInRadius;
            private _eCnt = [_center, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius;

            if (!_timerStarted) then {
                if (_pCnt > 0) then {
                    _timerStarted = true;
                    _timerStart = time;
                    _lastWaveTime = time - _maxInterval; // allow immediate first wave
                    if (!_armedHintSent) then {
                        _armedHintSent = true;
                        private _txt = format [
                            "<t size='1.1' color='#A0D0A0'>POINT DEFENSE</t><br/><br/><t color='#E0E0E0'>Hold clock started — defend for %1 minutes.</t>",
                            _durMinLabel
                        ];
                        [_txt] remoteExec ["FADE_showMissionHint", 0];
                    };
                };
            } else {
                if (_eCnt > 0 && { _pCnt <= 0 }) exitWith {
                    ["FAILED", "Zone lost — enemy entered while no players were present."] call _fnc_finish;
                    true
                };
                if ((time - _timerStart) >= _durationSec) exitWith {
                    ["SUCCEEDED", format ["Point held for %1 minutes.", _durMinLabel]] call _fnc_finish;
                    true
                };

                // Marker contest colours (players = friendly presence for PD)
                if (_mArea != "" && { _mIcon != "" }) then {
                    [_center, _zoneRadius, true, _pCnt, _eCnt, _mArea, _mIcon, _markerFriendly, _markerEnemy, {}, ""] call FADE_zone_tickInvasionHold;
                };

                private _waveAlive = [_waveUnits] call FADE_pd_countWaveAlive;
                private _totalAlive = [_allWaveUnits] call FADE_pd_countWaveAlive;
                private _cleared = (_waveSpawned <= 0) || { _waveAlive <= (((_waveSpawned * _clearPct) max 1) min _waveSpawned) };
                private _intervalOk = (time - _lastWaveTime) >= _maxInterval;
                if ((_cleared || _intervalOk) && { _totalAlive < _maxConcurrent }) then {
                    _waveIdx = _waveIdx + 1;
                    private _useVeh = random 1 < _vehChance;
                    // Alternate early: wave 1 INF, wave 2 VEH bias
                    if (_waveIdx == 1) then { _useVeh = false };
                    if (_waveIdx == 2) then { _useVeh = true };
                    private _spawned = if (_useVeh) then {
                        [_taskId, _center, _zoneRadius, _enemyUnits, _sideEnemy, _scaleOpforCount, _waveIdx, _waveVehs] call FADE_pd_spawnVehWave
                    } else {
                        [_taskId, _center, _zoneRadius, _enemyUnits, _sideEnemy, _scaleOpforCount, _waveIdx] call FADE_pd_spawnInfWave
                    };
                    if (count _spawned > 0) then {
                        _waveUnits = _spawned;
                        _waveSpawned = count _spawned;
                        _allWaveUnits append _spawned;
                        _lastWaveTime = time;
                    } else {
                        // Retry sooner if spawn failed
                        _lastWaveTime = time - (_maxInterval * 0.5);
                        _waveIdx = _waveIdx - 1;
                    };
                };
            };
            false
        };

        if (missionNamespace getVariable ["FADE_pdAborted_" + _taskId, false]) then {
            if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"])) then {
                [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
            };
        };

        {
            if (!isNull _x) then { deleteVehicle _x };
        } forEach _flavourObjs;
        [_taskId, "", _player, 45] call FADE_mission_completeCleanup;
        missionNamespace setVariable ["FADE_pdAborted_" + _taskId, nil];
    };
};

missionNamespace setVariable ["FADE_runMission_PointDefense", FADE_runMission_PointDefense];
missionNamespace setVariable ["FADE_pd_findAdjacentCivZonePos", FADE_pd_findAdjacentCivZonePos];
missionNamespace setVariable ["FADE_pd_pickInfSpawnPos", FADE_pd_pickInfSpawnPos];
missionNamespace setVariable ["FADE_pd_spawnInfWave", FADE_pd_spawnInfWave];
missionNamespace setVariable ["FADE_pd_spawnVehWave", FADE_pd_spawnVehWave];
