// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_ClearArea = {
    private _missionType = missionNamespace getVariable ["FADE_missionRun_missionType", ""];
    private _destPos = missionNamespace getVariable ["FADE_missionRun_destPos", [0,0,0]];
    private _player = missionNamespace getVariable ["FADE_missionRun_player", objNull];
    private _evadeePlayers = missionNamespace getVariable ["FADE_missionRun_evadeePlayers", []];
    private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
    private _mapAnchor = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
    private _friendlyUnits = missionNamespace getVariable ["FADE_missionRun_friendlyUnits", []];
    private _enemyUnits = missionNamespace getVariable ["FADE_missionRun_enemyUnits", []];
    private _sideFriendly = missionNamespace getVariable ["FADE_missionRun_sideFriendly", west];
    private _sideEnemy = missionNamespace getVariable ["FADE_missionRun_sideEnemy", east];
    private _markerFriendly = missionNamespace getVariable ["FADE_missionRun_markerFriendly", "ColorWEST"];
    private _markerEnemy = missionNamespace getVariable ["FADE_missionRun_markerEnemy", "ColorEAST"];
    private _dryPos = missionNamespace getVariable ["FADE_surfaceIsDry", {}];
    private _taskId = missionNamespace getVariable ["FADE_missionRun_taskId", ""];
    private _operationName = missionNamespace getVariable ["FADE_missionRun_operationName", ""];
    private _operationNameUpper = missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""];
    private _briefGuiTail = missionNamespace getVariable ["FADE_missionRun_briefGuiTail", ""];
    private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", {}];
    private _enemyFactionName = missionNamespace getVariable ["FADE_missionRun_enemyFactionName", ""];
    private _zeroAlphaDisplayName = missionNamespace getVariable ["FADE_missionRun_zeroAlphaDisplayName", ""];
    private _isGlobalMission = missionNamespace getVariable ["FADE_missionRun_isGlobalMission", false];
    private _basePos = missionNamespace getVariable ["FADE_missionRun_basePos", [0,0,0]];
    private _unitCount = missionNamespace getVariable ["FADE_missionRun_unitCount", 6];
    private _unitClasses = missionNamespace getVariable ["FADE_missionRun_unitClasses", []];
    private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {}];
    private _fnc_createMissionTask = missionNamespace getVariable ["FADE_mission_createTask", {}];
    private _showAssignedHint = missionNamespace getVariable ["FADE_mission_showAssignedHint", {}];
    private _defaultSituationTaskText = missionNamespace getVariable ["FADE_missionRun_defaultSituationTaskText", ""];
    private _defaultExecutionTaskText = missionNamespace getVariable ["FADE_missionRun_defaultExecutionTaskText", ""];
    private _defaultAdminTaskText = missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""];
    private _defaultCommandTaskText = missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""];
    private _defaultSituationHtml = missionNamespace getVariable ["FADE_missionRun_defaultSituationHtml", ""];
    private _defaultSituationHintHtml = missionNamespace getVariable ["FADE_missionRun_defaultSituationHintHtml", ""];
    private _friendlyPlayerCount = missionNamespace getVariable ["FADE_missionRun_friendlyPlayerCount", 0];
    private _friendlyFactionName = missionNamespace getVariable ["FADE_missionRun_friendlyFactionName", ""];
    private _estimatedOpforCount = missionNamespace getVariable ["FADE_missionRun_estimatedOpforCount", 0];
    private _opforCountFactor = missionNamespace getVariable ["FADE_missionRun_opforCountFactor", 1];
    private _intelFormatter = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
    private _topographyGrid = missionNamespace getVariable ["FADE_missionRun_topographyGrid", "UNKNOWN"];
    private _topographyArea = missionNamespace getVariable ["FADE_missionRun_topographyArea", ""];
    // Use same resolved list as rest of Missions.sqf (FADE_resolveScenarioEnemyUnits  -  scenario faction first)
    private _enemyUnitsCA = +_enemyUnits;
    _enemyUnitsCA = [_enemyUnitsCA] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsCA == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Use only classnames from our list (no createUnit with side default that could spawn CSAT)
    private _baseClassCA = _enemyUnitsCA select 0;
    private _useTown = if (_fromMapClick) then { true } else { random 1 > 0.5 };
    private _center = _destPos;
    private _campObjects = [];
    // Must exist before camp branch: stationary spawns push into _allGroups (was after town/camp block - undefined variable)
    private _allGroups = [];
    if (_useTown) then {
        if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
            _center = +_mapAnchor;
            if (count _center < 3) then { _center set [2, 0] };
        } else {
            private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
            if (count _civZones > 0) then {
                private _zoneName = selectRandom _civZones;
                private _trig = missionNamespace getVariable [_zoneName, objNull];
                if (!isNull _trig) then { _center = getPosATL _trig };
            };
        };
    } else {
        _center = [[_destPos, 0, 400, 100, 1, 0.3, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
        // BIS_fnc_findSafePos returns scalar 0 on failure  -  do not use count on that
        if (!(_center isEqualType []) || { count _center < 2 }) then { _center = _destPos };
        if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
        // Multiple camp compositions to choose from randomly for variety
        private _campVariants = [
            // Variant A: patrol forward base
            [
                ["Land_TentA_F", 12, 0], ["Land_TentDome_F", 15, 180], ["Land_CampingTable_F", 8, 90],
                ["Campfire_burning_F", 6, 270], ["Box_NATO_Ammo_F", 18, 45], ["Box_NATO_Support_F", 18, 315]
            ],
            // Variant B: dug-in position with sandbags
            [
                ["Land_BagFence_Round_F", 5, 0], ["Land_BagFence_Round_F", 5, 90], ["Land_BagFence_Round_F", 5, 180],
                ["Land_TentA_F", 16, 225], ["Campfire_burning_F", 4, 315], ["Box_NATO_Ammo_F", 20, 60]
            ],
            // Variant C: roadside checkpoint
            [
                ["Land_Barrier_01_wide_F", 8, 0], ["Land_Barrier_01_wide_F", 8, 180],
                ["Land_CampingTable_F", 6, 90], ["Campfire_burning_F", 5, 270],
                ["Land_TentDome_F", 14, 45], ["Box_NATO_Ammo_F", 16, 135]
            ],
            // Variant D: logistics camp
            [
                ["Land_TentA_F", 10, 30], ["Land_TentA_F", 10, 150], ["Land_TentDome_F", 14, 270],
                ["Land_CampingTable_F", 7, 60], ["Land_CampingChair_V2_F", 8, 100],
                ["Box_NATO_Ammo_F", 20, 0], ["Box_NATO_Support_F", 20, 180], ["Campfire_burning_F", 5, 230]
            ],
            // Variant E: minimal hide
            [
                ["Land_TentDome_F", 8, 0], ["Campfire_burning_F", 5, 180],
                ["Box_NATO_Ammo_F", 12, 90], ["Land_CampingTable_F", 10, 270]
            ]
        ];
        private _campComp = selectRandom _campVariants;
        {
            _x params ["_cls", "_dist", "_angle"];
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [[_p, 0, 2, 0, 1, 0.3, 0, [], _p], _p] call FADE_findSafePosArray;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _obj = createVehicle [_cls, _p, [], 0, "NONE"];
                _obj setPosATL _p;
                _campObjects pushBack _obj;
                [_taskId, _obj] call FADE_missionEnt_registerObject;
            };
        } forEach _campComp;

        // Stationary enemies at the camp itself (ambient combat anims like HVT/Hostage guards)
        private _stationaryCount = [3 + floor random 5, 1] call _scaleOpforCount;
        private _campCenterArea = [[_center, 0, 20, 2, 1, 0.4, 0, [], _center], _center] call FADE_findSafePosArray;
        if (!(_campCenterArea isEqualType []) || { count _campCenterArea < 2 }) then { _campCenterArea = _center };
        for "_si" from 0 to (_stationaryCount - 1) do {
            private _angle = (_si / _stationaryCount) * 360 + (random 30 - 15);
            private _dist = 3 + random 12;
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [[_p, 0, 2, 0, 1, 0.3, 0, [], _p], _p] call FADE_findSafePosArray;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _cls = selectRandom _enemyUnitsCA;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _p;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                } else { deleteGroup _grp };
            };
        };
    };
    if (count _center >= 2 && { count _center < 3 }) then { _center = [(_center select 0), (_center select 1), 0] };
    private _areaRadius = if (_useTown) then { 280 } else { 120 };
    private _caGarExtra = missionNamespace getVariable ["FADE_garrisonClearAreaSearchExtraM", 150];
    private _caBldChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _buildingsAll = nearestObjects [_center, ["House", "Building"], _areaRadius + _caGarExtra];
    private _buildings = (_buildingsAll select { random 1 < _caBldChance });
    if (count _buildings == 0 && { count _buildingsAll > 0 }) then { _buildings = +_buildingsAll };
    private _usedPositions = [];
    private _maxUnitsPerBuilding = 2;
    private _maxGarrisonTotal = [35, 8] call _scaleOpforCount;
    private _vgCa = missionNamespace getVariable ["FADE_vg_register", {}];
    private _misOwnCa = format ["mis:%1", _taskId];
    {
        private _bld = _x;
        private _bps = _bld buildingPos -1;
        private _addedThisBuilding = 0;
        private _slotATL = [];
        for "_i" from 0 to (count _bps - 1) do {
            if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
            if (_addedThisBuilding >= _maxUnitsPerBuilding) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                _slotATL pushBack _pos;
                _usedPositions pushBack _pos;
                _addedThisBuilding = _addedThisBuilding + 1;
            };
        };
        if (count _slotATL > 0) then {
            if (!(_vgCa isEqualTo {})) then {
                private _st = createHashMap;
                _st set ["owner", _misOwnCa];
                _st set ["groupsRef", _allGroups];
                _st set ["tryBarrel", true];
                _st set ["barrelMinDistPlayersM", -1];
                _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                private _bC = getPosATL _bld;
                if (count _bC < 3) then { _bC = [(_bC select 0), (_bC select 1), 0] };
                _st set ["barrelCenter", _bC];
                _st set ["barrelsRef", _campObjects];
                [_bld, _slotATL, +_enemyUnitsCA, _st] call _vgCa;
            } else {
                private _grp = createGroup _sideEnemy;
                {
                    private _pos = +_x;
                    private _cls = selectRandom _enemyUnitsCA;
                    private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                    if (!isNull _u) then {
                        _u setPos _pos;
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    };
                } forEach _slotATL;
                if (count units _grp > 0) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _allGroups pushBack _grp;
                } else { deleteGroup _grp };
            };
        };
        if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
    } forEach _buildings;
    private _numPatrols = [2 + floor random 3, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 30 + random (_areaRadius - 30);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 5, 1] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsCA) then { _enemyUnitsCA select _k } else { _baseClassCA };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _a = _w * 90 + (random 30);
                    private _d = 40 + random (_areaRadius - 40);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };
    private _areaVehicles = [];
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_enemyVehList isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        _enemyVehList = [_ef] call FADE_getEnemyVehiclesForFaction;
    };
    private _landVehClasses = _enemyVehList select { !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } };
    if (count _landVehClasses > 0) then {
        private _roads = _center nearRoads _areaRadius;
        if (count _roads > 0) then {
            private _numVeh = [1 + floor random 3, 1] call _scaleOpforCount;
            _numVeh = _numVeh min count _roads;
            private _roadShuf = _roads call BIS_fnc_arrayShuffle;
            for "_nv" from 0 to (_numVeh - 1) do {
                private _roadObj = _roadShuf select _nv;
                private _roadPos = getPosATL _roadObj;
                if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
                private _vClass = selectRandom _landVehClasses;
                private _veh = createVehicle [_vClass, _roadPos, [], 0, "NONE"];
                if (!isNull _veh) then {
                    _veh setPosATL _roadPos;
                    _areaVehicles pushBack _veh;
                    [_taskId, _veh] call FADE_missionEnt_registerVehicle;
                    private _vehGrp = createGroup _sideEnemy;
                    private _driver = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                    if (!isNull _driver) then { _driver moveInDriver _veh };
                    if (_veh emptyPositions "gunner" > 0) then {
                        private _g = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _g) then { _g moveInGunner _veh };
                    };
                    if (_veh emptyPositions "commander" > 0) then {
                        private _c = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _c) then { _c moveInCommander _veh };
                    };
                    [_veh, _enemyUnitsCA] call FADE_ensureEnemyVehicleGunner;
                    [_vehGrp] call FAC_applyEnemyScenarioToGroup;
                    _vehGrp setBehaviour "SAFE";
                    _vehGrp setSpeedMode "LIMITED";
                    private _wpAngle = random 360;
                    private _wpDist = 30 + random 170;
                    private _wpPos = [(_center select 0) + _wpDist * (cos _wpAngle), (_center select 1) + _wpDist * (sin _wpAngle), 0];
                    _wpPos = [[_wpPos, 0, 20, 10, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
                    if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                        if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
                        private _wp = _vehGrp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                    };
                    _allGroups pushBack _vehGrp;
                };
            };
        };
    };
    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    private _vgPendCa = missionNamespace getVariable ["FADE_vg_pendingMenForOwner", {}];
    if (!(_vgPendCa isEqualTo {})) then { _initialCount = _initialCount + ([_misOwnCa] call _vgPendCa) };
    if (_initialCount == 0) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _areaVehicles;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies in area.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _markerName = "FADE_clear_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
        [_taskId, _markerName] call FADE_missionEnt_registerMarker;
        _marker setMarkerType "mil_objective";
        _marker setMarkerColor _markerEnemy;
        _marker setMarkerText _operationName;
        private _grid = mapGridPosition _center;
        [_player, _taskId, "Destroy at least 80% of enemy forces in the area.", "Clear Area", _center, "attack"] call _fnc_createMissionTask;
        private _brief = format ["CLEAR AREA%1%1Objective (approx.): Grid %2 (%3)%1%1Clear and secure the area. Reduce enemy presence to the task's completion threshold; see Tasks for specific objectives and rules.", toString [10], _grid, if (_useTown) then { "occupied town" } else { "enemy camp" }] + _briefGuiTail;
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#FFFFFF'>Grid: %1 -- %2</t><br/><br/><t color='#FFFFFF'>Destroy 80%%+ of enemy forces.</t>", _grid, if (_useTown) then { "town" } else { "camp" }]] call _showAssignedHint;
        [_player, "Clear Area"] call FADE_notifyOthersMissionStarted;
        private _caDetect = (_areaRadius + 180) max 320;
        [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
        [_taskId, _center, _basePos, _enemyUnitsCA, _allGroups, _caDetect] call FADE_counterAttackStart;
        private _clearTimeout = 900;
        [_taskId, _allGroups, _initialCount, _markerName, _player, _campObjects, _areaVehicles, _clearTimeout, _misOwnCa] spawn {
            params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_campObjects", "_areaVehicles", "_timeout", "_misOwnCa"];
            private _start = time;
            private _vgPendF = missionNamespace getVariable ["FADE_vg_pendingMenForOwner", {}];
            waitUntil {
                sleep 0.5;
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
                if (time - _start > _timeout) exitWith { true };
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                private _pend = if (!(_vgPendF isEqualTo {})) then { [_misOwnCa] call _vgPendF } else { 0 };
                if ((_alive + _pend) <= _initialCount * 0.2) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    true
                } else { false };
            };
            if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                private _pend2 = if (!(_vgPendF isEqualTo {})) then { [_misOwnCa] call _vgPendF } else { 0 };
                if ((_alive + _pend2) <= _initialCount * 0.2) then { [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState } else { [_taskId, "CANCELED"] call BIS_fnc_taskSetState };
            };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
        };
    };
};

