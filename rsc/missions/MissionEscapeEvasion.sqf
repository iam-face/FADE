// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_EscapeEvasion = {
    (call FADE_missionRun_getContext) params [
        "_missionType", "_destPos", "_player", "_evadeePlayers", "_fromMapClick", "_mapAnchor",
        "_friendlyUnits", "_enemyUnits", "_sideFriendly", "_sideEnemy", "_markerFriendly", "_markerEnemy",
        "_dryPos", "_taskId", "_operationName", "_operationNameUpper", "_briefGuiTail",
        "_mkrJitter", "_enemyFactionName", "_zeroAlphaDisplayName", "_isGlobalMission", "_basePos",
        "_unitCount", "_unitClasses", "_scaleOpforCount", "_fnc_createMissionTask", "_showAssignedHint",
        "_defaultSituationTaskText", "_defaultExecutionTaskText", "_defaultAdminTaskText", "_defaultCommandTaskText",
        "_defaultSituationHtml", "_defaultSituationHintHtml", "_friendlyPlayerCount", "_friendlyFactionName",
        "_estimatedOpforCount", "_opforCountFactor", "_intelFormatter", "_topographyGrid", "_topographyArea"
    ];
    private _enemyUnitsEe = +_enemyUnits;
    _enemyUnitsEe = [_enemyUnitsEe] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsEe == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No enemy units configured."] call FADE_missionErrorHint;
    };
    private _zoneCenter = +_destPos;
    if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };
    private _applyGrpEe = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_applyGrpEe isEqualTo {}) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "Scenario apply function missing."] call FADE_missionErrorHint;
    };
    private _allGroupsEe = [];
    private _eeVgFireObjs = [];
    private _garCap = 20;
    private _guardCap = 15;
    private _eeGarRad = missionNamespace getVariable ["FADE_garrisonEeBuildingSearchRadiusM", 900];
    private _eeBldChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _bldsEeFull = (nearestObjects [_zoneCenter, ["House", "Building"], _eeGarRad]) select { count (_x buildingPos -1) >= 1 };
    private _bldsEe = (_bldsEeFull select { random 1 < _eeBldChance });
    if (count _bldsEe == 0 && { count _bldsEeFull > 0 }) then { _bldsEe = +_bldsEeFull };
    _bldsEe = _bldsEe call BIS_fnc_arrayShuffle;
    private _garCount = 0;
    private _vgEe = missionNamespace getVariable ["FADE_vg_register", {}];
    private _misEe = format ["mis:%1", _taskId];
    {
        if (_garCount >= _garCap) exitWith {};
        private _bldEe = _x;
        private _bps = (_bldEe buildingPos -1) call BIS_fnc_arrayShuffle;
        private _slotEe = [];
        private _spawnedB = 0;
        {
            if (_garCount >= _garCap) exitWith {};
            private _pos = _x;
            if (!(_pos isEqualType []) || { count _pos < 2 }) then { continue };
            if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
            if ([_pos] call _dryPos) then {
                _slotEe pushBack _pos;
                _garCount = _garCount + 1;
                _spawnedB = _spawnedB + 1;
            };
        } forEach _bps;
        if (_spawnedB > 0) then {
            if (!(_vgEe isEqualTo {})) then {
                private _st = createHashMap;
                _st set ["owner", _misEe];
                _st set ["groupsRef", _allGroupsEe];
                _st set ["facApply", false];
                _st set ["groupApply", _applyGrpEe];
                _st set ["tryBarrel", true];
                _st set ["barrelMinDistPlayersM", -1];
                _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                private _bC = getPosATL _bldEe;
                if (count _bC < 3) then { _bC = [(_bC select 0), (_bC select 1), 0] };
                _st set ["barrelCenter", _bC];
                _st set ["barrelsRef", _eeVgFireObjs];
                [_bldEe, _slotEe, +_enemyUnitsEe, _st] call _vgEe;
            } else {
                private _bldGrp = createGroup _sideEnemy;
                {
                    private _pos = +_x;
                    private _u = _bldGrp createUnit [selectRandom _enemyUnitsEe, _pos, [], 0, "NONE"];
                    if (!isNull _u) then {
                        _u setPosATL _pos;
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    };
                } forEach _slotEe;
                [_bldGrp] call _applyGrpEe;
                _allGroupsEe pushBack _bldGrp;
            };
        };
    } forEach _bldsEe;

    private _gd = 0;
    while { _gd < _guardCap } do {
        private _gp = [];
        for "_tryGd" from 1 to 18 do {
            private _ang = random 360;
            private _rd = 25 + random 675;
            private _gR = _zoneCenter getPos [_rd, _ang];
            _gp = [[_gR, 0, 22, 5, 1, 0.35, 0, [], _gR], _gR] call FADE_findSafePosArray;
            if (_gp isEqualType [] && { count _gp >= 2 } && { [_gp] call _dryPos }) exitWith {};
            _gp = [];
        };
        if (_gp isEqualType [] && { count _gp >= 2 }) then {
            _gp = [(_gp select 0), (_gp select 1), (_gp param [2, 0])];
            private _gg = createGroup _sideEnemy;
            private _ug = _gg createUnit [selectRandom _enemyUnitsEe, _gp, [], 0, "NONE"];
            if (!isNull _ug) then {
                [_gg] call _applyGrpEe;
                _ug setPosATL _gp;
                _ug setUnitPos "MIDDLE";
                [_ug, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroupsEe pushBack _gg;
                _gd = _gd + 1;
            } else {
                deleteGroup _gg;
            };
        };
    };

    private _findPatrolSpawnEe = {
        params ["_zc", "_evs", "_minPl", "_minZc"];
        private _out = [];
        for "_try" from 0 to 79 do {
            private _dir = random 360;
            private _dist = _minZc + random 3500;
            private _cand = _zc getPos [_dist, _dir];
            _cand = [[_cand, 0, 45, 18, 1, 0.35, 0, [], _cand], _cand] call FADE_findSafePosArray;
            if (!(_cand isEqualType []) || { count _cand < 2 }) then { } else {
                if ([_cand] call _dryPos) then {
                    if (_cand distance2D _zc >= _minZc) then {
                        private _bad = false;
                        { if (alive _x && { _cand distance2D _x < _minPl }) exitWith { _bad = true } } forEach _evs;
                        if (!_bad) exitWith { _out = [(_cand select 0), (_cand select 1), (_cand param [2, 0])]; };
                    };
                };
            };
        };
        if (count _out < 2) then {
            for "_fb" from 1 to 25 do {
                private _f = _zc getPos [2500 + random 2200, random 360];
                if (count _f < 3) then { _f = [(_f select 0), (_f select 1), 0] };
                if ([_f] call _dryPos) exitWith { _out = _f };
            };
        };
        _out
    };

    {
        if (isNull _x) then { } else {
        private _sp = [_zoneCenter, _evadeePlayers, 500, 1000] call _findPatrolSpawnEe;
        private _psz = 4 + (floor random 5);
        private _hGrp = createGroup _sideEnemy;
        for "_k" from 0 to (_psz - 1) do {
            private _cls = if (_k < count _enemyUnitsEe) then { _enemyUnitsEe select _k } else { _enemyUnitsEe select 0 };
            private _hu = _hGrp createUnit [_cls, _sp, [], 0, "NONE"];
            if (!isNull _hu) then { _hu setPosATL _sp };
        };
        if (count units _hGrp > 0) then {
            [_hGrp] call _applyGrpEe;
            _allGroupsEe pushBack _hGrp;
        } else {
            deleteGroup _hGrp;
        };
        };
    } forEach _evadeePlayers;

    private _eeVgPend = missionNamespace getVariable ["FADE_vg_pendingMenForOwner", {}];
    private _eePendingMen = if (!(_eeVgPend isEqualTo {})) then { [_misEe] call _eeVgPend } else { 0 };
    if (count _allGroupsEe == 0 && { _eePendingMen == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "Could not spawn Escape &amp; Evasion OPFOR."] call FADE_missionErrorHint;
    };

    missionNamespace setVariable ["FADE_dynRb_escapeZone", +_zoneCenter];

    {
        [] remoteExec ["FADE_clientStripEvadeeGPS", _x];
    } forEach _evadeePlayers;

    private _eeNearestCivCenterToPos = {
        params ["_pos"];
        if (count _pos < 2) exitWith { [] };
        private _best = [];
        private _bestD = 1e12;
        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        {
            private _tr = missionNamespace getVariable [_x, objNull];
            if (!isNull _tr) then {
                private _zc = getPosATL _tr;
                if (count _zc >= 2) then {
                    private _d = (_pos distance2D [(_zc select 0), (_zc select 1)]);
                    if (_d < _bestD) then {
                        _bestD = _d;
                        _best = [(_zc select 0), (_zc select 1), (_zc param [2, 0])];
                    };
                };
            };
        } forEach _zones;
        _best
    };

    {
        private _evp = _x;
        if (isNull _evp) then { } else {
            private _tp = [];
            for "_attempt" from 0 to 24 do {
                private _dir = random 360;
                private _dist = 500 + random 201;
                private _raw = _zoneCenter getPos [_dist, _dir];
                _tp = [[_raw, 0, 14, 5, 1, 0.4, 0, [], _raw], _raw] call FADE_findSafePosArray;
                if (_tp isEqualType [] && { count _tp >= 2 }) then {
                    _tp = [(_tp select 0), (_tp select 1), (_tp param [2, 0])];
                    private _d2 = _tp distance2D _zoneCenter;
                    if (_d2 >= 480 && { _d2 <= 750 }) exitWith {};
                };
                _tp = [];
            };
            if (count _tp < 2) then {
                private _dir = random 360;
                private _dist = 500 + random 201;
                _tp = _zoneCenter getPos [_dist, _dir];
                _tp = [(_tp select 0), (_tp select 1), (_tp param [2, 0])];
            };
            private _faceTown = [_tp, _zoneCenter] call BIS_fnc_dirTo;
            private _heliAnchor = [_tp] call _eeNearestCivCenterToPos;
            if (count _heliAnchor < 2) then { _heliAnchor = +_zoneCenter };
            _evp setVariable ["FADE_eeHeliAnchor", _heliAnchor, false];
            [_tp, _faceTown] remoteExec ["FADE_clientTeleportPos", _evp];
        };
    } forEach _evadeePlayers;

    // Dedicated MP: wait for client move to replicate, then remove OPFOR dismounts within 150 m of any evadee.
    sleep 1.2;
    {
        private _evCull = _x;
        if (!isNull _evCull && { alive _evCull } && { isPlayer _evCull }) then {
            private _near = (_evCull nearEntities [["Man"], 150]) select {
                alive _x && { !isPlayer _x } && { side _x == _sideEnemy }
            };
            { deleteVehicle _x } forEach _near;
        };
    } forEach _evadeePlayers;

    private _prunedEe = [];
    {
        if (!isNull _x) then {
            if (({ alive _x } count units _x) > 0) then {
                _prunedEe pushBack _x;
            } else {
                deleteGroup _x;
            };
        };
    } forEach _allGroupsEe;
    _allGroupsEe = _prunedEe;

    private _fnc_eeApplyCivZonePatrol = {
        params ["_grps", "_zc", "_dry"];
        {
            private _grp = _x;
            if (isNull _grp || { ({ alive _x } count units _grp) == 0 }) then { } else {
                {
                    if (alive _x) then {
                        _x switchMove "";
                        _x setUnitPos "AUTO";
                    };
                } forEach units _grp;
                _grp setBehaviour "SAFE";
                _grp setCombatMode "YELLOW";
                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                private _added = 0;
                private _nWp = 3 + (floor random 3);
                for "_wi" from 1 to _nWp do {
                    private _tryPos = [];
                    for "_tj" from 1 to 15 do {
                        private _ang = random 360;
                        private _rd = 35 + random 580;
                        private _raw = _zc getPos [_rd, _ang];
                        _tryPos = [[_raw, 0, 38, 6, 0, 0.45, 0, [], _raw], _raw] call FADE_findSafePosArray;
                        if (_tryPos isEqualType [] && { count _tryPos >= 2 } && { [_tryPos] call _dry }) exitWith {};
                        _tryPos = [];
                    };
                    if (count _tryPos >= 2) then {
                        private _wp = _grp addWaypoint [_tryPos, -1];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointBehaviour "SAFE";
                        _wp setWaypointSpeed "LIMITED";
                        _added = _added + 1;
                    };
                };
                if (_added > 0) then {
                    private _cyc = _grp addWaypoint [waypointPosition [_grp, 0], -1];
                    _cyc setWaypointType "CYCLE";
                };
            };
        } forEach _grps;
    };
    [_allGroupsEe, _zoneCenter, _dryPos] call _fnc_eeApplyCivZonePatrol;

    if (count _allGroupsEe == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "Escape &amp; Evasion: no OPFOR left after spawn proximity cull."] call FADE_missionErrorHint;
    };

    [_allGroupsEe, _basePos] call FADE_registerEnemyRetreat;
    [_taskId, _allGroupsEe] call FADE_missionEnt_bindGroups;

    missionNamespace setVariable ["FADE_eeEntities_" + _taskId, [_allGroupsEe, _eeVgFireObjs]];
    missionNamespace setVariable ["FADE_eeAborted_" + _taskId, false];
    missionNamespace setVariable ["FADE_eeQrfVehs_" + _taskId, []];
    missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, []];

    private _sfEe = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _eeMissionTxt = "Separated personnel must survive and return to friendly base. Any evadee KIA fails the mission.";
    private _eeExecTxt = "<t align='left' color='#C0C0C0'>GPS and map markers denied. Navigate by terrain; coordinate on assigned radio channels. Reach extraction within 1000 m of base.</t>";
    [_player, _taskId, _eeMissionTxt, "Escape & Evasion", _zoneCenter, "run", "", _eeExecTxt, true] call _fnc_createMissionTask;

    private _eeGrid = if (count _zoneCenter >= 2) then { mapGridPosition _zoneCenter } else { "N/A" };
    private _briefEe = format ["ESCAPE & EVASION%1%1Denied area (approx.): Grid %2%1%1Separated personnel must evade and reach extraction. No GPS — use radio and navigation. Extraction coordination and ROE are on task.", toString [10], _eeGrid] + _briefGuiTail;
    if (!isNull _player) then {
        _player setVariable ["FADE_myMissionBrief", _briefEe, true];
    };
    [format ["<t color='#FFFFFF'>Evadees dispersed in the denied area. No grid given — navigate by terrain and comms. RTB within 1000 m; all must survive.</t>"]] call _showAssignedHint;
    [_player, "Escape & Evasion"] call FADE_notifyOthersMissionStarted;

    // OPFOR search helicopter: faction heli (or FADE_opforAir fallback list), orbit waypoints on zone geometry only  -  never player positions.
    private _eePickSearchHeliClass = {
        private _air = [] call FADE_getEnemyAirVehicleClasses;
        _air = _air select { _x isKindOf "Helicopter" };
        if (_air isEqualTo []) then {
            _air = +FADE_opforAir_fallbackHeliClasses;
            _air = _air select { isClass (configFile >> "CfgVehicles" >> _x) && { _x isKindOf "Helicopter" } };
        };
        if (_air isEqualTo []) exitWith { "O_Heli_Light_02_dynamicLoadout_F" };
        selectRandom _air
    };

    private _eeDeleteSearchHeli = {
        params ["_veh", "_pilotGrp", "_cargoGrp"];
        if (!isNull _cargoGrp) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _cargoGrp;
            deleteGroup _cargoGrp;
        };
        if (!isNull _veh) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
            private _dg = group driver _veh;
            if (!isNull _dg) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
                deleteGroup _dg;
            };
            deleteVehicle _veh;
        } else {
            if (!isNull _pilotGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _pilotGrp;
                deleteGroup _pilotGrp;
            };
        };
    };

    private _eeSpawnSearchHeli = {
        params ["_tid", "_zc", "_crewUnits", "_applyLoc", "_sideEn"];
        private _zc2 = [_zc select 0, _zc select 1];
        private _mapMinA = missionNamespace getVariable ["FADE_mapMin", 0];
        private _mapMaxA = missionNamespace getVariable ["FADE_mapMax", worldSize];
        private _edgePad = 200;
        private _class = [] call _eePickSearchHeliClass;
        private _dirFrom = random 360;
        private _dist = 2600 + random 1400;
        private _spawn2 = [
            (_zc2 select 0) + _dist * (sin _dirFrom),
            (_zc2 select 1) + _dist * (cos _dirFrom)
        ];
        _spawn2 set [0, (_spawn2 select 0) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
        _spawn2 set [1, (_spawn2 select 1) max (_mapMinA + _edgePad) min (_mapMaxA - _edgePad)];
        private _alt = (getTerrainHeightASL [_spawn2 select 0, _spawn2 select 1]) + 260 + random 200;
        private _spawnPos = [_spawn2 select 0, _spawn2 select 1, _alt];
        private _face = ((_zc2 select 1) - (_spawn2 select 1)) atan2 ((_zc2 select 0) - (_spawn2 select 0));
        private _veh = createVehicle [_class, _spawnPos, [], 0, "FLY"];
        if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
        _veh setDir _face;
        { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
        private _grp = createGroup _sideEn;
        private _driver = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
        if (!isNull _driver) then { _driver moveInDriver _veh; _grp selectLeader _driver };
        if (_veh emptyPositions "gunner" > 0) then {
            private _gn = _grp createUnit [selectRandom _crewUnits, _spawnPos, [], 0, "NONE"];
            if (!isNull _gn) then { _gn moveInGunner _veh };
        };
        if (isNull driver _veh) exitWith {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
            deleteGroup _grp;
            deleteVehicle _veh;
            [objNull, grpNull, grpNull]
        };
        [_veh, _crewUnits] call FADE_ensureEnemyVehicleGunner;
        [_grp] call _applyLoc;
        _grp setGroupIdGlobal [format ["OPF-EE-SRCH-%1", floor random 999]];
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _veh flyInHeight (70 + floor random 60);
        private _orbitR = 520 + random 280;
        private _nPts = 6;
        private _firstWp = [];
        for "_wi" from 0 to (_nPts - 1) do {
            private _ang = (_wi * (360 / _nPts)) + random 25;
            private _p2 = _zc2 getPos [_orbitR, _ang];
            _p2 = [[_p2, 0, 120, 22, 1, 0.35, 0, [], _p2], _p2] call FADE_findSafePosArray;
            if (!(_p2 isEqualType []) || { count _p2 < 2 }) then { _p2 = _zc2 getPos [_orbitR, _ang] };
            private _atlp = [(_p2 select 0), (_p2 select 1), 0];
            if (_wi == 0) then { _firstWp = _atlp };
            private _wp = _grp addWaypoint [_atlp, _wi];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "AWARE";
            _wp setWaypointCombatMode "RED";
        };
        if (count _firstWp >= 2) then {
            private _wpc = _grp addWaypoint [_firstWp, _nPts];
            _wpc setWaypointType "CYCLE";
        };
        [ _veh, _grp, grpNull ]
    };

    private _eeDeleteQrf = {
        params ["_tid"];
        private _lst = missionNamespace getVariable ["FADE_eeQrfVehs_" + _tid, []];
        {
            private _v = _x;
            if (!isNull _v) then {
                private _cg = _v getVariable ["FADE_eeQrfCargoGrp", grpNull];
                if (!isNull _cg) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
                    deleteGroup _cg;
                };
                { if (!isNull _x) then { deleteVehicle _x } } forEach crew _v;
                private _dg = group driver _v;
                if (!isNull _dg) then {
                    { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
                    deleteGroup _dg;
                };
                if (!isNull _v) then { deleteVehicle _v };
            };
        } forEach _lst;
        missionNamespace setVariable ["FADE_eeQrfVehs_" + _tid, []];
    };

    private _eeSpawnQrf = {
        params ["_tid", "_detP", "_zc", "_baseQ", "_enemyUnitsLoc", "_applyLoc", "_sideEn"];
        [_tid] call _eeDeleteQrf;
        private _staging = _zc getPos [2200 + random 1800, random 360];
        private _roadHit = [_staging, 500, [], -1, [], getPosATL _detP] call FADE_findOpforGroundVehicleRoadSpawn;
        if (_roadHit isEqualTo []) exitWith {};
        _roadHit params ["_roadPos", "_dir"];
        if !([_roadPos] call _dryPos) exitWith {};
        private _flEe = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
        if (!isNull _detP && { !(_flEe isEqualTo {}) }) then { [getPosATL _detP, 220] call _flEe };
        private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
        if (_vehClasses isEqualTo []) then {
            private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
            _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
        };
        private _soft = [];
        {
            if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
                if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
            };
        } forEach _vehClasses;
        private _minCargo = 4;
        private _vehPick = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
        if (count _vehPick == 0) then {
            private _landAll = _vehClasses select { !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") } };
            _vehPick = [_landAll, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
        };
        if (count _vehPick == 0) exitWith {};
        private _vClass = selectRandom _vehPick;
        private _vehGrp = createGroup _sideEn;
        private _veh = createVehicle [_vClass, _roadPos, [], 0, "NONE"];
        if (isNull _veh) exitWith { deleteGroup _vehGrp };
        _veh setPosATL _roadPos;
        _veh setDir _dir;
        _veh setVectorUp surfaceNormal _roadPos;
        _veh engineOn true;
        private _driver = _vehGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
        if (!isNull _driver) then {
            _driver moveInDriver _veh;
            _vehGrp selectLeader _driver;
        };
        if (_veh emptyPositions "gunner" > 0) then {
            private _gn = _vehGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
            if (!isNull _gn) then { _gn moveInGunner _veh };
        };
        [_vehGrp] call _applyLoc;
        _vehGrp setBehaviour "AWARE";
        _vehGrp setCombatMode "RED";
        private _cargoGrp = grpNull;
        private _seats = (_veh emptyPositions "cargo") max 0;
        if (_seats > 0) then {
            _cargoGrp = createGroup _sideEn;
            for "_c" from 0 to ((_seats min 6) - 1) do {
                private _u = _cargoGrp createUnit [selectRandom _enemyUnitsLoc, _roadPos, [], 0, "NONE"];
                if (!isNull _u) then { _u moveInCargo _veh };
            };
            if (count units _cargoGrp > 0) then { [_cargoGrp] call _applyLoc };
        };
        [_veh, _enemyUnitsLoc] call FADE_ensureEnemyVehicleGunner;
        [_vehGrp] call _applyLoc;
        _veh setVariable ["FADE_eeQrfCargoGrp", _cargoGrp];
        private _tgtPos = getPosATL _detP;
        private _wp1 = _vehGrp addWaypoint [_tgtPos, 80];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        private _wp2 = _vehGrp addWaypoint [_tgtPos, 25];
        _wp2 setWaypointType "SAD";
        [_veh, _vehGrp, _cargoGrp, _tid, _detP] spawn {
            params ["_veh", "_vehGrp", "_cargoGrp", "_tid", "_detP"];
            scriptName "FADE_ee_qrfWp";
            private _eeWpIv = (missionNamespace getVariable ["FADE_qrfHuntWaypointIntervalS", 60]) max 15;
            while {
                alive _veh && {!isNull _veh} &&
                {!(((_tid call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]))} &&
                {!(missionNamespace getVariable ["FADE_eeAborted_" + _tid, false])}
            } do {
                sleep _eeWpIv;
                if (!alive _veh || { isNull _veh }) exitWith {};
                if (isNull _detP || { !alive _detP }) exitWith {};
                while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                private _p = getPosATL _detP;
                private _w1 = _vehGrp addWaypoint [_p, 80];
                _w1 setWaypointType "MOVE";
                _w1 setWaypointSpeed "FULL";
                private _w2 = _vehGrp addWaypoint [_p, 20];
                _w2 setWaypointType "SAD";
            };
            if (!isNull _veh && { alive _veh } && {!isNull _cargoGrp} && { count units _cargoGrp > 0 } && {!isNull _detP} && { alive _detP }) then {
                {
                    unassignVehicle _x;
                    _x action ["GetOut", _veh];
                } forEach units _cargoGrp;
            };
        };
        private _cur = missionNamespace getVariable ["FADE_eeQrfVehs_" + _tid, []];
        _cur pushBack _veh;
        missionNamespace setVariable ["FADE_eeQrfVehs_" + _tid, _cur];
        [_tid, _veh] call FADE_missionEnt_registerVehicle;
    };

    [_taskId, _evadeePlayers, _zoneCenter, _basePos, _enemyUnitsEe, _applyGrpEe, _sideEnemy, _eeDeleteQrf, _eeSpawnQrf, _eeSpawnSearchHeli, _eeDeleteSearchHeli, _player] spawn {
        params ["_taskId", "_evadeePlayers", "_zoneCenter", "_basePos", "_enemyUnitsEe", "_applyGrpEe", "_sideEnemy", "_eeDeleteQrf", "_eeSpawnQrf", "_eeSpawnSearchHeli", "_eeDeleteSearchHeli", "_player"];
        scriptName "FADE_ee_main";
        private _lastQrf = -1e9;
        private _eeHeliVeh = objNull;
        private _eeHeliGrp = grpNull;
        private _eeHeliCargo = grpNull;
        private _eeHeliSortieUntil = -1;
        private _eeHeliEverSpawned = false;
        private _eeHeliNextAfter = 1e12;
        private _heliDistGate = missionNamespace getVariable ["FADE_eeSearchHeliMinDistFromAnchor", 1500];
        waitUntil {
            sleep 5;
            if (missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false]) exitWith { true };
            private _st = _taskId call BIS_fnc_taskState;
            if (_st in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (!isNull _eeHeliVeh) then {
                if (!alive _eeHeliVeh || { isNull _eeHeliVeh } || { time >= _eeHeliSortieUntil }) then {
                    [_eeHeliVeh, _eeHeliGrp, _eeHeliCargo] call _eeDeleteSearchHeli;
                    _eeHeliVeh = objNull;
                    _eeHeliGrp = grpNull;
                    _eeHeliCargo = grpNull;
                    _eeHeliSortieUntil = -1;
                    _eeHeliNextAfter = time + (1200 + random 600);
                    missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, []];
                };
            } else {
                if (_st == "ASSIGNED") then {
                    private _allowHeli = false;
                    if (!_eeHeliEverSpawned) then {
                        {
                            if (!isNull _x && { alive _x } && { isPlayer _x }) then {
                                private _ac = _x getVariable ["FADE_eeHeliAnchor", _zoneCenter];
                                if ((getPosATL _x) distance2D _ac >= _heliDistGate) exitWith { _allowHeli = true };
                            };
                        } forEach _evadeePlayers;
                    } else {
                        if (time >= _eeHeliNextAfter) then { _allowHeli = true };
                    };
                    if (_allowHeli) then {
                        private _hRes = [_taskId, _zoneCenter, _enemyUnitsEe, _applyGrpEe, _sideEnemy] call _eeSpawnSearchHeli;
                        if (!isNull (_hRes param [0, objNull])) then {
                            _eeHeliVeh = _hRes select 0;
                            _eeHeliGrp = _hRes select 1;
                            _eeHeliCargo = _hRes select 2;
                            [_taskId, _eeHeliVeh] call FADE_missionEnt_registerVehicle;
                            if (!isNull _eeHeliGrp) then { [_taskId, _eeHeliGrp] call FADE_missionEnt_registerGroup };
                            _eeHeliSortieUntil = time + 720 + random 360;
                            missionNamespace setVariable ["FADE_eeSearchHeli_" + _taskId, _hRes];
                            _eeHeliEverSpawned = true;
                        } else {
                            if (_eeHeliEverSpawned) then { _eeHeliNextAfter = time + 300 };
                        };
                    };
                };
            };
            private _liveE = _evadeePlayers select { !isNull _x && { alive _x } && { isPlayer _x } };
            private _anyDead = false;
            {
                if (isNull _x) then { _anyDead = true } else { if (!alive _x) then { _anyDead = true } };
            } forEach _evadeePlayers;
            if (_anyDead) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                true
            };
            if (count _liveE == 0) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                true
            };
            private _allHome = true;
            {
                if ((_x distance2D _basePos) > 1000) then { _allHome = false };
            } forEach _liveE;
            if (_allHome) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            if ((time - _lastQrf) >= 600) then {
                private _detP = objNull;
                {
                    private _p = _x;
                    if (!isNull _p && { alive _p }) then {
                        {
                            private _u = _x;
                            if (side _u == _sideEnemy && { alive _u } && { _u isKindOf "Man" } && { _u distance2D _p < 550 }) then {
                                if (_u knowsAbout _p > 1.59) then { _detP = _p };
                            };
                        } forEach allUnits;
                    };
                    if (!isNull _detP) exitWith {};
                } forEach _liveE;
                if (!isNull _detP) then {
                    [_taskId, _detP, _zoneCenter, _basePos, _enemyUnitsEe, _applyGrpEe, _sideEnemy] call _eeSpawnQrf;
                    _lastQrf = time;
                };
            };
            false
        };
        if ((_taskId call BIS_fnc_taskState) == "ASSIGNED" && { missionNamespace getVariable ["FADE_eeAborted_" + _taskId, false] }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        { if (!isNull _x) then { _x setVariable ["FADE_eeHeliAnchor", nil]; } } forEach _evadeePlayers;
        [_taskId, "", _player, 0] call FADE_mission_completeCleanup;
    };
};

