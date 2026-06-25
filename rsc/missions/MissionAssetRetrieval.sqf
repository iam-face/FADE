// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_AssetRetrieval = {
    private _missionType = missionNamespace getVariable ["FADE_missionRun_missionType", ""];
    private _destPos = missionNamespace getVariable ["FADE_missionRun_destPos", [0,0,0]];
    private _player = missionNamespace getVariable ["FADE_missionRun_player", objNull];
    private _evadeePlayers = missionNamespace getVariable ["FADE_missionRun_evadeePlayers", []];
    private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
    private _mapAnchor = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
    private _mapPickResolvedR = missionNamespace getVariable ["FADE_missionRun_mapPickResolvedRadius", -1];
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
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _enemyUnitsAsset = +_enemyUnits;
    _enemyUnitsAsset = [_enemyUnitsAsset] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsAsset == 0) then { _enemyUnitsAsset = +_enemyUnits };
    private _baseEnemyClass = _enemyUnitsAsset select 0;
    private _assetBranch = if (random 1 < 0.66) then { 1 } else { 2 };

    // Branch 2 (33%): recover enemy vehicle and return it near base.
    if (_assetBranch == 2) exitWith {
        // Prefer RHS UAZ (themed recovery target) but degrade gracefully so the branch
        // doesn't dead-end when only vanilla content is loaded. Pick the first class that
        // actually exists in CfgVehicles, falling back through CSAT/AAF/NATO unarmed offroads.
        private _assetCandidates = [
            "RHS_UAZ_MSV_01",
            "rhsgref_BRDM2_msv",
            "O_LSV_02_unarmed_F",
            "O_T_LSV_02_unarmed_black_F",
            "I_C_Offroad_02_unarmed_F",
            "C_Offroad_01_F",
            "B_LSV_01_unarmed_F"
        ];
        private _vehicleClass = "";
        {
            if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith { _vehicleClass = _x };
        } forEach _assetCandidates;
        if (_vehicleClass == "") exitWith {
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No recovery vehicle class available for this scenario.</t>"] remoteExec ["FADE_showMissionHint", _player];
        };
        private _vehicleCfg = configFile >> "CfgVehicles" >> _vehicleClass;
        private _vehicleName = if (isClass _vehicleCfg) then { getText (_vehicleCfg >> "displayName") } else { _vehicleClass };
        if (_vehicleName == "") then { _vehicleName = _vehicleClass };

        private _spawnRoadVehicleInZone = {
            params ["_zoneCenter", "_vehClass"];
            private _roads = _zoneCenter nearRoads 500;
            if (_roads isEqualTo []) exitWith { [objNull, []] };
            _roads = _roads call BIS_fnc_arrayShuffle;
            private _result = [objNull, []];

            {
                private _road = _x;
                private _roadPos = getPosATL _road;
                if (_roadPos isEqualType [] && { count _roadPos < 3 }) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };

                private _candidate = [[_roadPos, 0, 8, 5, 1, 0.2, 0, [], _roadPos], _roadPos] call FADE_findSafePosArray;
                if !(_candidate isEqualType [] && { count _candidate >= 2 }) then { _candidate = _roadPos };
                if (_candidate isEqualType [] && { count _candidate < 3 }) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
                if !([_candidate] call _dryPos) then { continue };

                if !(isOnRoad _candidate || { (_candidate distance2D _roadPos) <= 12 }) then { continue };
                private _nearVehicles = nearestObjects [_candidate, ["LandVehicle", "Air", "Ship"], 5];
                if (count _nearVehicles > 0) then { continue };

                private _veh = createVehicle [_vehClass, _candidate, [], 0, "NONE"];
                if (isNull _veh) then { continue };

                private _dir = random 360;
                private _conn = roadsConnectedTo _road;
                if (count _conn > 0) then { _dir = _road getDir (_conn select 0) };

                _veh allowDamage false;
                _veh setPosATL _candidate;
                _veh setDir _dir;
                _veh setVectorUp surfaceNormal _candidate;
                _veh setVelocity [0, 0, 0];
                _veh setFuel 1;
                _veh setDamage 0;
                clearWeaponCargoGlobal _veh;
                clearMagazineCargoGlobal _veh;
                clearItemCargoGlobal _veh;
                clearBackpackCargoGlobal _veh;
                [_veh] spawn { params ["_v"]; sleep 2; if (!isNull _v) then { _v allowDamage true } };

                if (!alive _veh || { !canMove _veh }) then {
                    deleteVehicle _veh;
                    continue;
                };

                _result = [_veh, _candidate];
                if (!isNull _veh) exitWith {};
            } forEach _roads;

            _result
        };

        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        private _zonesEligible = [_zones, _mapAnchor, 1500, _mapPickResolvedR] call FADE_fnc_assetZonesNearMapClick;
        private _assetVehicle = objNull;
        private _center = +_destPos;
        if (_fromMapClick && { count _mapAnchor >= 2 }) then {
            private _roadsNear = _mapAnchor nearRoads 500;
            if (count _roadsNear > 0) then {
                private _spawnRes = [_mapAnchor, _vehicleClass] call _spawnRoadVehicleInZone;
                private _vehTry = _spawnRes param [0, objNull];
                private _posTry = _spawnRes param [1, []];
                if (!isNull _vehTry) then {
                    _assetVehicle = _vehTry;
                    [_taskId, _assetVehicle] call FADE_missionEnt_registerVehicle;
                    _center = _posTry;
                };
            };
        };

        if (isNull _assetVehicle && { count _zonesEligible > 0 }) then {
            private _maxPasses = 10;
            private _pass = 0;
            while { isNull _assetVehicle && { _pass < _maxPasses } } do {
                _pass = _pass + 1;
                if (!_fromMapClick) then { _zonesEligible = _zonesEligible call BIS_fnc_arrayShuffle };
                {
                    if (!isNull _assetVehicle) exitWith {};
                    private _trig = missionNamespace getVariable [_x, objNull];
                    if (isNull _trig) then { continue };
                    private _zoneCenter = getPosATL _trig;
                    if (_zoneCenter isEqualType [] && { count _zoneCenter < 3 }) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };
                    private _spawnRes = [_zoneCenter, _vehicleClass] call _spawnRoadVehicleInZone;
                    private _vehTry = _spawnRes param [0, objNull];
                    private _posTry = _spawnRes param [1, []];
                    if (!isNull _vehTry) then {
                        _assetVehicle = _vehTry;
                        [_taskId, _assetVehicle] call FADE_missionEnt_registerVehicle;
                        _center = _posTry;
                    };
                } forEach _zonesEligible;
            };
        };

        if (isNull _assetVehicle) exitWith {
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn the recovery vehicle on a safe road near an eligible civ zone.</t>"] remoteExec ["FADE_showMissionHint", _player];
        };

        private _allGroups = [];
        private _guardCountSpawned = 0;
        private _guardCap = 20;

        private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
        _guardCount = _guardCount min _guardCap;
        for "_g" from 0 to (_guardCount - 1) do {
            if (_guardCountSpawned >= _guardCap) exitWith {};
            private _guardPos = [];
            for "_tryG" from 1 to 16 do {
                _guardPos = [[_center, 12, 100, 3, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
                if (_guardPos isEqualType [] && { count _guardPos >= 2 } && { [_guardPos] call _dryPos }) exitWith {};
                _guardPos = [];
            };
            if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
                if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
                private _guardGrp = createGroup _sideEnemy;
                private _u = _guardGrp createUnit [selectRandom _enemyUnitsAsset, _guardPos, [], 0, "NONE"];
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

        private _areaRadius = 220;
        private _numPatrols = [2 + floor random 2, 1] call _scaleOpforCount;
        for "_g" from 0 to (_numPatrols - 1) do {
            private _sp = [];
            for "_tryPat" from 1 to 18 do {
                private _angle = random 360;
                private _dist = 40 + random ((_areaRadius - 50) max 1);
                private _rough = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
                _sp = [[_rough, 0, 15, 3, 1, 0.4, 0, [], _rough], _rough] call FADE_findSafePosArray;
                if (_sp isEqualType [] && { count _sp >= 2 } && { [_sp] call _dryPos }) exitWith {};
                _sp = [];
            };
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _size = [3 + floor random 3, 2] call _scaleOpforCount;
                private _grp = createGroup _sideEnemy;
                for "_k" from 0 to (_size - 1) do {
                    private _cls = if (_k < count _enemyUnitsAsset) then { _enemyUnitsAsset select _k } else { _baseEnemyClass };
                    private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                    if (!isNull _u) then { _u setPosATL _sp };
                };
                if (count units _grp > 0) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _grp setBehaviour "SAFE";
                    _grp setCombatMode "YELLOW";
                    for "_w" from 0 to 2 do {
                        private _wpPos = [];
                        for "_tryWp" from 1 to 12 do {
                            private _a = _w * 120 + (random 40);
                            private _d = 50 + random ((_areaRadius - 50) max 1);
                            private _wR = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                            _wpPos = [[_wR, 0, 12, 3, 1, 0.4, 0, [], _wR], _wR] call FADE_findSafePosArray;
                            if (_wpPos isEqualType [] && { count _wpPos >= 2 } && { [_wpPos] call _dryPos }) exitWith {};
                            _wpPos = [];
                        };
                        if (count _wpPos >= 2) then {
                            private _wp = _grp addWaypoint [_wpPos, 0];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointSpeed "LIMITED";
                            if (_w == 2) then { _wp setWaypointType "CYCLE" };
                        };
                    };
                    _allGroups pushBack _grp;
                } else {
                    deleteGroup _grp;
                };
            };
        };

        [_allGroups, _basePos] call FADE_registerEnemyRetreat;

        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, [_assetVehicle]];
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

        private _topoVeh = [_center] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
        private _vehSituationTaskText = if (_intelFormatter isEqualTo {}) then {
            format [
                "<t align='left' color='#FFFFFF'>Branch: VEHICLE RECOVERY</t><br/><t align='left' color='#FFFFFF'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#FFFFFF'>Enemy: %3 dismounts securing a recovery vehicle on roads; patrols in the area.</t><br/><t align='left' color='#FFFFFF'>Friendly: operating from base.</t>",
                _topoVeh select 0,
                _topoVeh select 1,
                _enemyFactionName
            ]
        } else {
            [
                "AssetRetrievalVeh",
                _center,
                _sideEnemy,
                _sideFriendly,
                _estimatedOpforCount,
                _opforCountFactor,
                _enemyFactionName,
                _friendlyFactionName,
                _friendlyPlayerCount,
                _topoVeh select 0,
                _topoVeh select 1,
                "#FFFFFF"
            ] call _intelFormatter
        };
        private _vehExecutionTaskText = format [
            "Branch task: vehicle recovery. Move to the objective marker (road/vehicle site). Clear local OPFOR, then recover the OPFOR %1 (drive, tow, or sling as available). Exfil by feasible route; vehicle must arrive operational within 1000 m of base. Mission fails if the vehicle is destroyed.",
            _vehicleName
        ];
        private _vehMissionDesc = format [
            "Branch: VEHICLE RECOVERY. Recover the OPFOR %1 and return it within 1000 m of base. Vehicle must remain operational.",
            _vehicleName
        ];
        [_player, _taskId, _vehMissionDesc, "Asset Retrieval", _center, "car", _vehSituationTaskText, _vehExecutionTaskText] call _fnc_createMissionTask;

        private _markerName = "FADE_asset_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
        [_taskId, _markerName] call FADE_missionEnt_registerMarker;
        _marker setMarkerType "mil_objective";
        _marker setMarkerColor "ColorYellow";
        _marker setMarkerText _operationName;

        private _grid = mapGridPosition _center;
        private _brief = format ["ASSET RETRIEVAL  -  VEHICLE%1%1Objective area (approx.): Grid %2%1%1Recover the enemy vehicle %3 and return it to base per task limits. Secure the site, clear threats, and move the asset by the best available method.", toString [10], _grid, _vehicleName] + _briefGuiTail;
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#FFCC00'>Branch: Vehicle recovery</t><br/><t color='#C0C0C0'>Asset vehicle: %2</t><br/><t color='#C0C0C0'>Return it to base (within 1000 m).</t>", _grid, _vehicleName]] call _showAssignedHint;
        [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

        private _arQrfPos = +_center;
        if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
        private _arDetect = (_areaRadius + 120) max 280;
        [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
        [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;

        [_taskId, _basePos, _markerName, _player, _allGroups, _assetVehicle] spawn {
            params ["_taskId", "_basePos", "_markerName", "_player", "_allGroups", "_assetVehicle"];
            private _baseDist = 1000;
            waitUntil {
                sleep 2;
                if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
                if (isNull _assetVehicle || { !alive _assetVehicle }) exitWith {
                    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Recovery vehicle destroyed.</t>"] remoteExec ["FADE_showMissionHint", _player];
                    true
                };
                if ((_assetVehicle distance _basePos) <= _baseDist) exitWith {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>Recovery vehicle returned to base.</t>"] remoteExec ["FADE_showMissionHint", _player];
                    true
                };
                false
            };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
            [_taskId, 45, _player] call FADE_missionEnt_scheduledCleanup;
        };
    };

    private _areaRadius = 220;
    private _house = objNull;
    private _houseBps = [];
    private _center = +_destPos;
    private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _zonesEligible = [_zones, _mapAnchor, 1500, _mapPickResolvedR] call FADE_fnc_assetZonesNearMapClick;

    if (_fromMapClick && { count _mapAnchor >= 2 }) then {
        private _buildingsNear = nearestObjects [_mapAnchor, ["House", "Building"], 500];
        private _suitableNear = [];
        {
            private _bps = _x buildingPos -1;
            if (count _bps >= 6 && { [getPosATL _x] call _dryPos }) then {
                _suitableNear pushBack [_x, _bps];
            };
        } forEach _buildingsNear;
        if (count _suitableNear > 0) then {
            _suitableNear = [_suitableNear, [], { (getPosATL (_x select 0)) distance2D _mapAnchor }, "ASCEND"] call BIS_fnc_sortBy;
            private _pick = _suitableNear select 0;
            _house = _pick param [0, objNull];
            _houseBps = _pick param [1, []];
            _center = getPosATL _house;
        };
    };

    if (isNull _house && { count _zonesEligible > 0 }) then {
        private _maxPasses = 12;
        private _pass = 0;
        while { isNull _house && { _pass < _maxPasses } } do {
            _pass = _pass + 1;
            if (!_fromMapClick) then { _zonesEligible = _zonesEligible call BIS_fnc_arrayShuffle };
            {
                if (!isNull _house) exitWith {};
                private _trig = missionNamespace getVariable [_x, objNull];
                if (isNull _trig) then { continue };
                private _zoneCenter = getPosATL _trig;
                if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };

                // Requested flow: list buildings in 500m around the selected zone center,
                // keep only those with at least 6 building positions, then pick one.
                private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 500];
                private _suitable = [];
                {
                    private _bps = _x buildingPos -1;
                    if (count _bps >= 6 && { [getPosATL _x] call _dryPos }) then {
                        _suitable pushBack [_x, _bps];
                    };
                } forEach _buildings;

                if (count _suitable > 0) exitWith {
                    private _pick = if (_fromMapClick) then {
                        private _sorted = [_suitable, [], { (getPosATL (_x select 0)) distance2D _mapAnchor }, "ASCEND"] call BIS_fnc_sortBy;
                        _sorted select 0
                    } else {
                        selectRandom _suitable
                    };
                    _house = _pick param [0, objNull];
                    _houseBps = _pick param [1, []];
                    _center = getPosATL _house;
                };
            } forEach _zonesEligible;
        };
    };

    if (isNull _house || { count _houseBps < 1 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No civ zone >=1500m from HQ had a building with at least 6 positions within 500m.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _assetClass = "Land_PlasticCase_01_small_gray_F";
    private _assetIdx = 0;
    if (count _houseBps >= 3) then {
        // Avoid first/last building positions  -  often outside.
        _assetIdx = 1 + floor random ((count _houseBps) - 2);
    };
    private _assetBp = _houseBps select _assetIdx;
    if (count _assetBp < 3) then { _assetBp = [(_assetBp select 0), (_assetBp select 1), 0] };
    private _intelObj = createVehicle [_assetClass, _assetBp, [], 0, "NONE"];
    if (isNull _intelObj) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Failed to spawn asset object.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    _intelObj setPosATL _assetBp;
    _intelObj setDir (getDir _house);

    private _assetCfg = configFile >> "CfgVehicles" >> _assetClass;
    private _assetName = if (isClass _assetCfg) then { getText (_assetCfg >> "displayName") } else { _assetClass };
    if (_assetName == "") then { _assetName = _assetClass };

    private _assetBarrel = objNull;
    private _barrelPos = [[_center, 8, 22, 2, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _assetBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        if (!isNull _assetBarrel) then { _assetBarrel setPosATL _barrelPos };
    };

    private _allGroups = [];
    private _vgArHintObjs = [];
    private _garrisonCount = 0;
    private _guardCountSpawned = 0;
    private _garrisonCap = 40;
    private _guardCap = 20;
    private _perNearbyBuildingCap = 3;
    for "_i" from 0 to ((count _houseBps) - 1) do {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        if (_i == _assetIdx) then { continue };
        private _pos = _houseBps select _i;
        if (count _pos >= 2 && { random 1 < 0.75 }) then {
            if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
            if !([_pos] call _dryPos) then { continue };
            private _grp = createGroup _sideEnemy;
            private _u = _grp createUnit [selectRandom _enemyUnitsAsset, _pos, [], 0, "NONE"];
            if (!isNull _u) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _u setPosATL _pos;
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                _allGroups pushBack _grp;
                _garrisonCount = _garrisonCount + 1;
            } else {
                deleteGroup _grp;
            };
        };
    };

    if (_garrisonCount == 0 && { _garrisonCap > 0 }) then {
        private _fallbackIdx = 0;
        if (_fallbackIdx == _assetIdx && { count _houseBps > 1 }) then { _fallbackIdx = 1 };
        private _fallbackPos = _houseBps select _fallbackIdx;
        if (count _fallbackPos < 3) then { _fallbackPos = [(_fallbackPos select 0), (_fallbackPos select 1), 0] };
        private _grp = createGroup _sideEnemy;
        private _u = _grp createUnit [_baseEnemyClass, _fallbackPos, [], 0, "NONE"];
        if (!isNull _u) then {
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _u setPosATL _fallbackPos;
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            _allGroups pushBack _grp;
            _garrisonCount = 1;
        } else {
            deleteGroup _grp;
        };
    };

    // Nearby-building garrison: wide ring around anchor; subset of buildings; each kept slot rolls FADE_vgNearbySlotChance (deferred spawn).
    private _nearRad = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    private _nearBldChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _nearSlotP = missionNamespace getVariable ["FADE_vgNearbySlotChance", 0.165];
    private _nearBuildingsFull = (nearestObjects [_center, ["House", "Building"], _nearRad]) select {
        !(_x isEqualTo _house) && { count (_x buildingPos -1) >= 1 } && { [getPosATL _x] call _dryPos }
    };
    private _nearBuildings = (_nearBuildingsFull select { random 1 < _nearBldChance });
    if (count _nearBuildings == 0 && { count _nearBuildingsFull > 0 }) then { _nearBuildings = +_nearBuildingsFull };
    private _vgAr = missionNamespace getVariable ["FADE_vg_register", {}];
    {
        if (_garrisonCount >= _garrisonCap) exitWith {};
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        private _slotATL = [];
        private _spawnedInBld = 0;
        {
            if (_spawnedInBld >= _perNearbyBuildingCap || { _garrisonCount >= _garrisonCap }) exitWith {};
            private _pos = _x;
            if (count _pos >= 2 && { random 1 < _nearSlotP }) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                if ([_pos] call _dryPos) then {
                    _slotATL pushBack _pos;
                    _spawnedInBld = _spawnedInBld + 1;
                };
            };
        } forEach _bldPos;

        if (_spawnedInBld > 0) then {
            if (!(_vgAr isEqualTo {})) then {
                private _st = createHashMap;
                _st set ["owner", format ["mis:%1", _taskId]];
                _st set ["groupsRef", _allGroups];
                _st set ["tryBarrel", true];
                _st set ["barrelMinDistPlayersM", -1];
                _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                private _bC = getPosATL _bld;
                if (count _bC < 3) then { _bC = [(_bC select 0), (_bC select 1), 0] };
                _st set ["barrelCenter", _bC];
                _st set ["barrelsRef", _vgArHintObjs];
                [_bld, _slotATL, +_enemyUnitsAsset, _st] call _vgAr;
            } else {
                private _bldGrp = createGroup _sideEnemy;
                {
                    private _pos = +_x;
                    private _u = _bldGrp createUnit [selectRandom _enemyUnitsAsset, _pos, [], 0, "NONE"];
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

    // Outside guards: individual units around the target house (within 100m), ambient-combat idle.
    private _guardCount = [3 + floor random 3, 1] call _scaleOpforCount;
    _guardCount = _guardCount min _guardCap;
    for "_g" from 0 to (_guardCount - 1) do {
        if (_guardCountSpawned >= _guardCap) exitWith {};
        private _guardPos = [];
        for "_tryG2" from 1 to 16 do {
            _guardPos = [[_center, 12, 100, 3, 1, 0.3, 0, [], _center], _center] call FADE_findSafePosArray;
            if (_guardPos isEqualType [] && { count _guardPos >= 2 } && { [_guardPos] call _dryPos }) exitWith {};
            _guardPos = [];
        };
        if (_guardPos isEqualType [] && { count _guardPos >= 2 }) then {
            if (count _guardPos < 3) then { _guardPos = [(_guardPos select 0), (_guardPos select 1), 0] };
            private _guardGrp = createGroup _sideEnemy;
            private _u = _guardGrp createUnit [selectRandom _enemyUnitsAsset, _guardPos, [], 0, "NONE"];
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

    private _numPatrols = [2 + floor random 2, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _sp = [];
        for "_tryPatI" from 1 to 18 do {
            private _angle = random 360;
            private _dist = 40 + random ((_areaRadius - 50) max 1);
            private _roughI = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _sp = [[_roughI, 0, 15, 3, 1, 0.4, 0, [], _roughI], _roughI] call FADE_findSafePosArray;
            if (_sp isEqualType [] && { count _sp >= 2 } && { [_sp] call _dryPos }) exitWith {};
            _sp = [];
        };
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsAsset) then { _enemyUnitsAsset select _k } else { _baseEnemyClass };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPosATL _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                _grp setCombatMode "YELLOW";
                for "_w" from 0 to 2 do {
                    private _wpPos = [];
                    for "_tryWpI" from 1 to 12 do {
                        private _a = _w * 120 + (random 40);
                        private _d = 50 + random ((_areaRadius - 50) max 1);
                        private _wRI = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                        _wpPos = [[_wRI, 0, 12, 3, 1, 0.4, 0, [], _wRI], _wRI] call FADE_findSafePosArray;
                        if (_wpPos isEqualType [] && { count _wpPos >= 2 } && { [_wpPos] call _dryPos }) exitWith {};
                        _wpPos = [];
                    };
                    if (count _wpPos >= 2) then {
                        private _wp = _grp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                        if (_w == 2) then { _wp setWaypointType "CYCLE" };
                    };
                };
                _allGroups pushBack _grp;
            } else {
                deleteGroup _grp;
            };
        };
    };

    [_allGroups, _basePos] call FADE_registerEnemyRetreat;

    private _assetObjects = [_intelObj];
    if (!isNull _assetBarrel) then { _assetObjects pushBack _assetBarrel };
    _assetObjects append _vgArHintObjs;
    { if (!isNull _x) then { [_taskId, _x] call FADE_missionEnt_registerObject } } forEach _assetObjects;

    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
    _intelObj addAction [
        "Secure intel package",
        {
            (_this select 3) params ["_taskId"];
            [_taskId, _this select 0, _this select 1] remoteExec ["FADE_assetIntelTakeServer", 2];
        },
        [_taskId],
        1.5,
        true,
        true,
        "",
        "(_this distance _target) < 3 && { alive _this }",
        3
    ];

    missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
    missionNamespace setVariable ["FADE_assetObjects_" + _taskId, _assetObjects];
    missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

    private _topoObj = [_center] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _objSituationTaskText = if (_intelFormatter isEqualTo {}) then {
        format [
            "<t align='left' color='#FFFFFF'>Branch: OBJECT RECOVERY</t><br/><t align='left' color='#FFFFFF'>Topography: Grid %1 | Area: %2</t><br/><t align='left' color='#FFFFFF'>Enemy: %3 dismounts securing an objective house; patrols in the area.</t><br/><t align='left' color='#FFFFFF'>Friendly: operating from base.</t>",
            _topoObj select 0,
            _topoObj select 1,
            _enemyFactionName
        ]
    } else {
        [
            "AssetRetrievalObj",
            _center,
            _sideEnemy,
            _sideFriendly,
            _estimatedOpforCount,
            _opforCountFactor,
            _enemyFactionName,
            _friendlyFactionName,
            _friendlyPlayerCount,
            _topoObj select 0,
            _topoObj select 1,
            "#FFFFFF"
        ] call _intelFormatter
    };
    private _objExecutionTaskText = format [
        "Branch task: object recovery. Move to the marked objective house, clear local OPFOR, and use scroll action to secure %1. After securing the object, RTB and move within 150 m of base to complete mission.",
        _assetName
    ];
    private _objMissionDesc = format [
        "Branch: OBJECT RECOVERY. Secure %1 inside the target house, then RTB (within 150 m of base).",
        _assetName
    ];
    [_player, _taskId, _objMissionDesc, "Asset Retrieval", _center, "search", _objSituationTaskText, _objExecutionTaskText] call _fnc_createMissionTask;

    private _markerName = "FADE_asset_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_center, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorYellow";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _center;
    private _brief = format ["ASSET RETRIEVAL  -  OBJECT%1%1Objective area (approx.): Grid %2%1%1Secure the target object %3 and RTB as instructed. Clear structures, recover the item, and move to extraction per the task.", toString [10], _grid, _assetName] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFCC00'>Branch: Object recovery</t><br/><t color='#FFFFFF'>Target object: %2</t><br/><t color='#FFFFFF'>Secure inside the house, then RTB (150 m).</t>", _grid, _assetName]] call _showAssignedHint;
    [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

    private _arQrfPos = +_center;
    if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
    private _arDetect = (_areaRadius + 120) max 280;
    [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;

    [_taskId, _center, _basePos, _markerName, _player, _allGroups, _assetObjects] spawn {
        params ["_taskId", "_center", "_basePos", "_markerName", "_player", "_allGroups", "_assetObjects"];
        private _baseDist = 150;
        waitUntil {
            sleep 2;
            if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (
                missionNamespace getVariable ["FADE_assetIntelTaken_" + _taskId, false] &&
                { !isNull _player } &&
                { alive _player } &&
                { (_player distance _basePos) <= _baseDist }
            ) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>Intel secured and returned to base.</t>"] remoteExec ["FADE_showMissionHint", _player];
                true
            };
            false
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
        [_taskId, 45, _player] call FADE_missionEnt_scheduledCleanup;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _assetObjects;
    };
};

