// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_SearchDestroy = {
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
    private _enemyUnitsSd = +_enemyUnits;
    _enemyUnitsSd = [_enemyUnitsSd] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsSd == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _baseClassSd = _enemyUnitsSd select 0;
    // Same civ-zone + near-center pattern as Hostage: random urban pos can land in empty ground  -  loop until
    // three enterable buildings (2+ buildingPos slots) exist within radius, trying random zones then every civ zone.
    private _minDistUrban = 1000;
    private _areaRadius = 250;
    private _trySdPickBuildings = {
        params ["_pos", "_radius"];
        if (count _pos < 2) exitWith { [[], []] };
        private _c = +_pos;
        if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
        private _buildings = nearestObjects [_c, ["House", "Building"], _radius];
        private _cands = _buildings call BIS_fnc_arrayShuffle;
        private _pickedTrial = [];
        {
            if (count _pickedTrial >= 3) exitWith {};
            private _bps = _x buildingPos -1;
            if (count _bps >= 2) then { _pickedTrial pushBack _x };
        } forEach _cands;
        if (count _pickedTrial >= 3) then {
            [_c, _pickedTrial select [0, 3]]
        } else {
            [[], []]
        };
    };
    private _center = [];
    private _picked = [];
    if (_fromMapClick) then {
        private _sdSearchCenter = if (count _mapAnchor >= 2) then { +_mapAnchor } else { +_destPos };
        private _res = [_sdSearchCenter, _areaRadius] call _trySdPickBuildings;
        _res params ["_cPos", "_bList"];
        if (count _bList >= 3) then {
            _center = _cPos;
            _picked = _bList;
        };
    } else {
        private _maxAttempts = 50;
        private _attempt = 0;
        while { _attempt < _maxAttempts } do {
            _attempt = _attempt + 1;
            private _tryPos = [_minDistUrban] call FADE_findMissionPosUrbanNearCenter;
            private _res = [_tryPos, _areaRadius] call _trySdPickBuildings;
            _res params ["_cPos", "_bList"];
            if (count _bList >= 3) exitWith {
                _center = _cPos;
                _picked = _bList;
            };
        };
    };
    if (count _picked < 3 && { !_fromMapClick }) then {
        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zones = _zones call BIS_fnc_arrayShuffle;
        {
            if (count _picked >= 3) exitWith {};
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if ((_zc distance _basePos) >= _minDistUrban) then {
                    private _tryPos = [[_zc, 50, 400, 5, 1, 0.5, 0, [], _zc], _zc] call FADE_findSafePosArray;
                    private _res2 = [_tryPos, _areaRadius] call _trySdPickBuildings;
                    _res2 params ["_cPos2", "_bList2"];
                    if (count _bList2 >= 3) then {
                        _center = _cPos2;
                        _picked = _bList2;
                    };
                };
            };
        } forEach _zones;
    };

    if (count _picked < 3) exitWith {
        [_player] call FADE_clearActiveMission;
        private _sdErr = if (_fromMapClick) then {
            "No town with three enterable buildings near your map click (searched up to whole map). Try a built-up area or use Random."
        } else {
            "No town with three enterable buildings near a civ zone. Try again or use a denser map."
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1</t>", _sdErr]] remoteExec ["FADE_showMissionHint", _player];
    };

    private _allGroups = [];
    private _garrisonCount = 0;
    private _sdCacheBuildings = [];
    private _misOwnSd = format ["mis:%1", _taskId];
    private _vgSd = missionNamespace getVariable ["FADE_vg_register", {}];
    {
        private _building = _x;
        private _bps = _building buildingPos -1;
        private _addedThis = 0;
        private _slotATL = [];
        for "_i" from 0 to (count _bps - 1) do {
            if (_addedThis >= 2) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                _slotATL pushBack _pos;
                _addedThis = _addedThis + 1;
                _garrisonCount = _garrisonCount + 1;
            };
        };
        if (count _slotATL > 0) then {
            private _garrisonedForCache = false;
            if (!(_vgSd isEqualTo {})) then {
                private _st = createHashMap;
                _st set ["owner", _misOwnSd];
                _st set ["groupsRef", _allGroups];
                private _vgId = [_building, _slotATL, +_enemyUnitsSd, _st] call _vgSd;
                _garrisonedForCache = _vgId >= 0;
            } else {
                private _spawnedUnits = 0;
                {
                    private _pos = +_x;
                    private _cls = selectRandom _enemyUnitsSd;
                    private _grp = createGroup _sideEnemy;
                    private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                    if (!isNull _u) then {
                        [_grp] call FAC_applyEnemyScenarioToGroup;
                        _u setPos _pos;
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                        _allGroups pushBack _grp;
                        _spawnedUnits = _spawnedUnits + 1;
                    } else { deleteGroup _grp };
                } forEach _slotATL;
                _garrisonedForCache = _spawnedUnits > 0;
            };
            if (_garrisonedForCache) then { _sdCacheBuildings pushBackUnique _building };
        };
    } forEach _picked;

    // Burning barrel outside each target building (same placement band as Asset Retrieval).
    private _sdBarrelObjs = [];
    private _sdVgHintObjs = [];
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        private _barrelPos = [[_buildingCenter, 8, 22, 2, 1, 0.3, 0, [], _buildingCenter], _buildingCenter] call FADE_findSafePosArray;
        if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
            _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
            private _barrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
            if (!isNull _barrel) then {
                _barrel setPosATL _barrelPos;
                _sdBarrelObjs pushBack _barrel;
            };
        };
    } forEach _picked;

    // Nearby-building garrison + outside guards: same caps / logic as Asset Retrieval (mission center = urban anchor).
    private _garrisonCap = 40;
    private _guardCap = 20;
    private _perNearbyBuildingCap = 3;
    private _guardCountSpawned = 0;
    private _nearRadSd = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    private _nearBldChanceSd = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _nearSlotSd = missionNamespace getVariable ["FADE_vgNearbySlotChance", 0.165];
    private _nearBuildingsFullSd = (nearestObjects [_center, ["House", "Building"], _nearRadSd]) select {
        !(_x in _picked) && { count (_x buildingPos -1) >= 1 }
    };
    private _nearBuildings = (_nearBuildingsFullSd select { random 1 < _nearBldChanceSd });
    if (count _nearBuildings == 0 && { count _nearBuildingsFullSd > 0 }) then { _nearBuildings = +_nearBuildingsFullSd };
    {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        private _slotATL = [];
        private _spawnedInBld = 0;
        {
            if (_spawnedInBld >= _perNearbyBuildingCap || { _garrisonCount >= _garrisonCap }) exitWith {};
            private _pos = _x;
            if (count _pos >= 2 && { random 1 < _nearSlotSd }) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                _slotATL pushBack _pos;
                _spawnedInBld = _spawnedInBld + 1;
            };
        } forEach _bldPos;

        if (_spawnedInBld > 0) then {
            if (!(_vgSd isEqualTo {})) then {
                private _st = createHashMap;
                _st set ["owner", _misOwnSd];
                _st set ["groupsRef", _allGroups];
                _st set ["tryBarrel", true];
                _st set ["barrelMinDistPlayersM", -1];
                _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                private _bC = getPosATL _bld;
                if (count _bC < 3) then { _bC = [(_bC select 0), (_bC select 1), 0] };
                _st set ["barrelCenter", _bC];
                _st set ["barrelsRef", _sdVgHintObjs];
                [_bld, _slotATL, +_enemyUnitsSd, _st] call _vgSd;
            } else {
                private _bldGrp = createGroup _sideEnemy;
                {
                    private _pos = +_x;
                    private _u = _bldGrp createUnit [selectRandom _enemyUnitsSd, _pos, [], 0, "NONE"];
                    if (!isNull _u) then {
                        _u setPosATL _pos;
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    };
                } forEach _slotATL;
                [_bldGrp] call FAC_applyEnemyScenarioToGroup;
                _allGroups pushBack _bldGrp;
            };
            _garrisonCount = _garrisonCount + _spawnedInBld;
        };
    } forEach _nearBuildings;

    private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
    _guardCount = _guardCount min _guardCap;
    for "_g" from 0 to (_guardCount - 1) do {
        if (_guardCountSpawned >= _guardCap) exitWith {};
        private _guardPos = [[_center, 12, 100, 3, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyUnitsSd, _guardPos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_guardGrp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _guardPos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroups pushBack _guardGrp;
                _guardCountSpawned = _guardCountSpawned + 1;
            } else {
                deleteGroup _guardGrp;
            };
        };
    };

    // GM ammo pile props: only buildings successfully registered/spawned as target garrisons can contain a cache.
    private _sdAmmoClasses = [
        "gm_ammobox_pile_small_03_empty",
        "gm_ammobox_pile_small_02_empty",
        "gm_ammobox_pile_large_02_empty",
        "Box_East_Ammo_F",
        "Box_NATO_Ammo_F",
        "Box_IND_Ammo_F"
    ];
    private _sdAmmoClassesOk = _sdAmmoClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    private _sdAmmoObjs = [];
    if (count _sdAmmoClassesOk > 0) then {
        {
            private _building = _x;
            private _bps = _building buildingPos -1;
            if (count _bps > 0) then {
                private _ammoBp = if (count _bps > 2) then { _bps select 2 } else { selectRandom _bps };
                if (count _ammoBp >= 2) then {
                    if (count _ammoBp < 3) then { _ammoBp = [(_ammoBp select 0), (_ammoBp select 1), 0] };
                    private _cls = selectRandom _sdAmmoClassesOk;
                    private _obj = createVehicle [_cls, _ammoBp, [], 0, "NONE"];
                    if (!isNull _obj) then {
                        _obj setPosATL _ammoBp;
                        _obj setDir ((getDir _building) + random 360);
                        _sdAmmoObjs pushBack _obj;
                    };
                };
            };
        } forEach _sdCacheBuildings;
    };

    private _sdCleanupObjs = _sdAmmoObjs + _sdBarrelObjs + _sdVgHintObjs;

    private _numPatrols = [2, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 40 + random (_areaRadius - 50);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsSd) then { _enemyUnitsSd select _k } else { _baseClassSd };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 2 do {
                    private _a = _w * 120 + (random 40);
                    private _d = 50 + random(_areaRadius - 50);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 2) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };

    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    private _vgPendSd = missionNamespace getVariable ["FADE_vg_pendingMenForOwner", {}];
    if (!(_vgPendSd isEqualTo {})) then { _initialCount = _initialCount + ([_misOwnSd] call _vgPendSd) };
    if (_initialCount == 0) exitWith {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdCleanupObjs;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, [_allGroups, _sdCleanupObjs]];
    missionNamespace setVariable ["FADE_sdAborted_" + _taskId, false];

    private _markerName = "FADE_sd_" + _taskId;
    private _zoneMarkerName = _markerName + "_zone";
    missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, _markerName];
    missionNamespace setVariable ["FADE_searchDestroyZoneMarker_" + _taskId, _zoneMarkerName];
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _zoneMarker = createMarker [_zoneMarkerName, _center];
    [_taskId, _zoneMarkerName] call FADE_missionEnt_registerMarker;
    _zoneMarker setMarkerShape "ELLIPSE";
    _zoneMarker setMarkerSize [_areaRadius, _areaRadius];
    _zoneMarker setMarkerBrush "Border";
    _zoneMarker setMarkerColor _markerEnemy;
    _zoneMarker setMarkerAlpha 0.45;
    private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _center;
    private _cacheCount = count _sdAmmoObjs;
    private _destroyPct = (missionNamespace getVariable ["FADE_searchDestroyCacheDestroyPct", 100]) max 0 min 100;
    private _requiredDestroy = if (_cacheCount > 0) then {
        ceil (_cacheCount * (_destroyPct / 100)) max 1
    } else {
        0
    };
    private _cacheObjectiveLine = if (_cacheCount > 0) then {
        format [
            "Intel: %1 enemy ammo caches in the zone. Destroy at least %2 (%3%%) to complete.",
            _cacheCount,
            _requiredDestroy,
            _destroyPct
        ]
    } else {
        format ["Intel: %1 suspected cache sites in the zone. Clear all defenders to complete.", count _picked]
    };
    private _sdExec = if (_cacheCount > 0) then {
        format [
            "<t align='left' color='#C0C0C0'>1. Search the marked zone (%1 m radius).<br/>2. Burning barrels mark buildings with enemy ammo caches.<br/>3. Locate and destroy at least %2 of %3 caches (%4%% required).<br/>4. Eliminate all defenders in the zone.</t>",
            _areaRadius,
            _requiredDestroy,
            _cacheCount,
            _destroyPct
        ]
    } else {
        format [
            "<t align='left' color='#C0C0C0'>1. Search the marked zone (%1 m radius).<br/>2. Burning barrels mark suspected cache buildings.<br/>3. Clear all defenders in the zone.</t>",
            _areaRadius
        ]
    };
    private _missionDesc = if (_cacheCount > 0) then {
        format [
            "Search the marked zone (%1 m radius). Destroy at least %2 of %3 ammo caches (%4%%) and eliminate all defenders.",
            _areaRadius,
            _requiredDestroy,
            _cacheCount,
            _destroyPct
        ]
    } else {
        format ["Search the marked zone (%1 m radius) and eliminate all defenders.", _areaRadius]
    };
    [_player, _taskId, _missionDesc, "Search & Destroy", _center, "attack", "", _sdExec] call _fnc_createMissionTask;
    private _brief = format [
        "SEARCH & DESTROY%1%1Search zone (approx.): Grid %2  -  %3 m radius%1%1%4%1Burning barrels outside buildings mark cache sites.",
        toString [10],
        _grid,
        _areaRadius,
        _cacheObjectiveLine
    ] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    private _hintCaches = if (_cacheCount > 0) then {
        format ["<t color='#FFFFFF'>Ammo caches: %1 (destroy %2  -  %3%%)</t><br/>", _cacheCount, _requiredDestroy, _destroyPct]
    } else {
        ""
    };
    private _hintObjective = if (_cacheCount > 0) then {
        format ["<t color='#FFFFFF'>Destroy at least %1 of %2 caches, then clear all defenders.</t>", _requiredDestroy, _cacheCount]
    } else {
        "<t color='#FFFFFF'>Clear all defenders inside the marked zone.</t>"
    };
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>Search radius: %2 m</t><br/>%3%4", _grid, _areaRadius, _hintCaches, _hintObjective]] call _showAssignedHint;
    [_player, "Search & Destroy"] call FADE_notifyOthersMissionStarted;

    private _sdDetect = (_areaRadius + 120) max 280;
    [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _center, _basePos, _enemyUnitsSd, _allGroups, _sdDetect] call FADE_counterAttackStart;

    private _sdTimeout = 900;
    [_taskId, _allGroups, _initialCount, _markerName, _player, _sdTimeout, _sdCleanupObjs, _misOwnSd, _sdAmmoObjs, _requiredDestroy] spawn {
        params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_timeout", "_sdCleanupObjs", "_misOwnSd", "_sdAmmoObjs", "_requiredDestroy"];
        private _start = time;
        private _vgPendF = missionNamespace getVariable ["FADE_vg_pendingMenForOwner", {}];
        private _fnc_cacheDestroyed = {
            params ["_obj"];
            isNull _obj || { !alive _obj } || { damage _obj >= 0.95 }
        };
        waitUntil {
            sleep 0.5;
            if (missionNamespace getVariable ["FADE_sdAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (time - _start > _timeout) exitWith { true };
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
            private _pend = if (!(_vgPendF isEqualTo {})) then { [_misOwnSd] call _vgPendF } else { 0 };
            private _enemiesCleared = (_alive == 0) && { _pend == 0 };
            private _destroyed = { [_x] call _fnc_cacheDestroyed } count _sdAmmoObjs;
            private _cachesCleared = if (count _sdAmmoObjs > 0) then {
                _destroyed >= _requiredDestroy
            } else {
                true
            };
            if (_enemiesCleared && _cachesCleared) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            false
        };
        if ((time - _start > _timeout) && { (_taskId call BIS_fnc_taskState) == "ASSIGNED" }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
    };
};

