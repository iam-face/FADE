// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_AssetRetrieval = {
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
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No enemy units configured."] call FADE_missionErrorHint;
    };

    private _enemyUnitsAsset = +_enemyUnits;
    _enemyUnitsAsset = [_enemyUnitsAsset] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsAsset == 0) then { _enemyUnitsAsset = +_enemyUnits };
    private _baseEnemyClass = _enemyUnitsAsset select 0;
    private _assetBranch = if (random 1 < 0.66) then { 1 } else { 2 };
    private _areaRadius = missionNamespace getVariable ["FADE_missionApproxZoneRadiusM", 55];

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
            [_player, "MISSION ERROR", "No recovery vehicle class available for this scenario."] call FADE_missionErrorHint;
        };
        private _vehicleCfg = configFile >> "CfgVehicles" >> _vehicleClass;
        private _vehicleName = if (isClass _vehicleCfg) then { getText (_vehicleCfg >> "displayName") } else { _vehicleClass };
        if (_vehicleName == "") then { _vehicleName = _vehicleClass };

        private _spawnRoadVehicleInZone = {
            params ["_zoneCenter", "_vehClass"];
            private _hit = [_zoneCenter, 350, [], -1, [], _zoneCenter] call FADE_findOpforGroundVehicleRoadSpawn;
            if (_hit isEqualTo []) exitWith { [objNull, []] };
            _hit params ["_candidate", "_dir"];
            private _veh = createVehicle [_vehClass, _candidate, [], 0, "NONE"];
            if (isNull _veh) exitWith { [objNull, []] };

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
                [objNull, []]
            } else {
                [_veh, _candidate]
            };
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
            if (!_fromMapClick && { count _destPos >= 2 }) then {
                _zonesEligible = [_zonesEligible, [], {
                    private _t = missionNamespace getVariable [_x, objNull];
                    if (isNull _t) exitWith { 1e15 };
                    (getPosATL _t) distance2D _destPos
                }, "ASCEND"] call BIS_fnc_sortBy;
            };
            private _maxPasses = 4;
            private _pass = 0;
            while { isNull _assetVehicle && { _pass < _maxPasses } } do {
                _pass = _pass + 1;
                private _zonesTry = +_zonesEligible;
                if (!_fromMapClick && { _pass > 1 }) then { _zonesTry = _zonesTry call BIS_fnc_arrayShuffle };
                if (count _zonesTry > 8) then { _zonesTry = _zonesTry select [0, 8] };
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
                } forEach _zonesTry;
            };
        };

        if (isNull _assetVehicle) exitWith {
            [_player] call FADE_clearActiveMission;
            [_player, "MISSION ERROR", "Could not spawn the recovery vehicle on a safe road near an eligible civ zone."] call FADE_missionErrorHint;
        };

        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, []];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, [_assetVehicle]];
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

        private _topoVeh = [_center] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
        private _vehSituationTaskText = if (_intelFormatter isEqualTo {}) then {
            format [
                "<t align='left' color='#FFD166'>ENEMY</t><br/><t align='left' color='#FFFFFF'>%1 dismounts securing a recovery vehicle on roads; patrols in the area.</t><br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/><t align='left' color='#FFFFFF'>CTB — task-organized from base.</t>",
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
        private _loreAppendFn = missionNamespace getVariable ["FADE_lore_appendSituationHtml", { params ["_s"]; _this select 0 }];
        _vehSituationTaskText = [_vehSituationTaskText] call _loreAppendFn;
        private _vehExecutionTaskText = format [
            "<t align='left' color='#C0C0C0'>Move to the objective marker (road/vehicle site). Clear local OPFOR, then recover the OPFOR %1 (drive, tow, or sling as available). Exfil by feasible route; vehicle must arrive operational within 1000 m of base. Vehicle must remain recoverable for exfil.</t>",
            _vehicleName
        ];
        private _vehMissionDesc = format [
            "Branch: VEHICLE RECOVERY — Grid %1 (%2). Recover the OPFOR %3 and return it within 1000 m of base. Vehicle must remain operational.",
            _topoVeh select 0,
            _topoVeh select 1,
            _vehicleName
        ];
        [_player, _taskId, _vehMissionDesc, "Asset Retrieval", _center, "car", _vehSituationTaskText, _vehExecutionTaskText] call _fnc_createMissionTask;

        private _markerName = "FADE_asset_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _markerOut = [_taskId, _markerName, _center, _areaRadius, "ColorOrange", "objective", _operationName, -1, -1, [_center]] call FADE_mission_createObjectiveMarker;

        private _grid = mapGridPosition _center;
        private _brief = format ["ASSET RETRIEVAL  -  VEHICLE%1%1Objective area (approx.): Grid %2%1%1Recover the enemy vehicle %3 and return it to base per task limits. Secure the site, clear threats, and move the asset by the best available method.", toString [10], _grid, _vehicleName] + _briefGuiTail;
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#FFCC00'>Branch: Vehicle recovery</t><br/><t color='#C0C0C0'>Asset vehicle: %2</t><br/><t color='#C0C0C0'>Return it to base (within 1000 m).</t>", _grid, _vehicleName]] call _showAssignedHint;
        [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

        private _arQrfPos = +_center;
        if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
        private _arDetect = (_areaRadius + 120) max 280;

        [
            _taskId, _basePos, _markerName, _player, _assetVehicle, _center, _areaRadius,
            _enemyUnitsAsset, _sideEnemy, _baseEnemyClass, _scaleOpforCount, _dryPos,
            _arQrfPos, _arDetect, _markerOut
        ] spawn {
            params [
                "_taskId", "_basePos", "_markerName", "_player", "_assetVehicle", "_center", "_areaRadius",
                "_enemyUnitsAsset", "_sideEnemy", "_baseEnemyClass", "_scaleOpforCount", "_dryPos",
                "_arQrfPos", "_arDetect", "_markerOut"
            ];
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
            missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
            [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
            [_taskId, "AssetRetrieval", _center, _markerOut, _allGroups, "ColorOrange"] call FADE_fieldIntel_startForMission;
            [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;
            private _baseDist = 1000;
            waitUntil {
                sleep 2;
                if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
                if (isNull _assetVehicle || { !alive _assetVehicle }) exitWith {
                    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                    [_player, "Recovery vehicle destroyed."] call FADE_missionFailHint;
                    true
                };
                if ((_assetVehicle distance _basePos) <= _baseDist) exitWith {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    [_player, "Recovery vehicle returned to base."] call FADE_missionSuccessHint;
                    true
                };
                false
            };
            [_taskId, _markerName, _player, 45] call FADE_mission_completeCleanup;
            missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
        };
    };

    private _house = objNull;
    private _houseBps = [];
    private _center = +_destPos;
    private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _zonesEligible = [_zones, _mapAnchor, 1500, _mapPickResolvedR] call FADE_fnc_assetZonesNearMapClick;

    private _tryBldFn = missionNamespace getVariable ["FADE_fnc_tryAssetRetrievalBuildingAtZone", {}];
    if (!_fromMapClick && { count _destPos >= 2 } && { !(_tryBldFn isEqualTo {}) }) then {
        private _fast = [_destPos, 1000] call _tryBldFn;
        _fast params ["_cFast", "_hFast", "_bpsFast"];
        if (!isNull _hFast) then {
            _house = _hFast;
            _houseBps = _bpsFast;
            _center = _cFast;
        };
    };

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
        private _maxPasses = 4;
        private _pass = 0;
        while { isNull _house && { _pass < _maxPasses } } do {
            _pass = _pass + 1;
            private _zonesTry = +_zonesEligible;
            if (!_fromMapClick && { _pass > 1 }) then { _zonesTry = _zonesTry call BIS_fnc_arrayShuffle };
            if (count _zonesTry > 10) then { _zonesTry = _zonesTry select [0, 10] };
            {
                if (!isNull _house) exitWith {};
                private _trig = missionNamespace getVariable [_x, objNull];
                if (isNull _trig) then { continue };
                private _zoneCenter = getPosATL _trig;
                if (count _zoneCenter < 3) then { _zoneCenter = [(_zoneCenter select 0), (_zoneCenter select 1), 0] };

                private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 500];
                if (count _buildings > 28) then {
                    _buildings = (_buildings call BIS_fnc_arrayShuffle) select [0, 28];
                };
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
            } forEach _zonesTry;
        };
    };

    if (isNull _house || { count _houseBps < 1 }) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No civ zone >=1500m from HQ had a building with at least 6 positions within 500m."] call FADE_missionErrorHint;
    };

    private _assetClass = missionNamespace getVariable ["FADE_recoverObjectClass", "Land_PlasticCase_01_small_gray_F"];
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
        [_player, "MISSION ERROR", "Failed to spawn asset object."] call FADE_missionErrorHint;
    };
    _intelObj setPosATL _assetBp;
    _intelObj setDir (getDir _house);

    private _assetName = [_assetClass] call (missionNamespace getVariable ["FADE_getRecoverObjectDisplayName", { _this select 0 }]);

    private _assetBarrel = objNull;
    private _barrelPos = [_center] call FADE_findOutdoorHintPos;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _assetBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        if (!isNull _assetBarrel) then { _assetBarrel setPosATL _barrelPos };
    };

    private _assetObjects = [_intelObj];
    if (!isNull _assetBarrel) then { _assetObjects pushBack _assetBarrel };
    { if (!isNull _x) then { [_taskId, _x] call FADE_missionEnt_registerObject } } forEach _assetObjects;

    [_intelObj, _taskId] call FADE_objective_addRecoverHoldAction;
    missionNamespace setVariable ["FADE_assetEntities_" + _taskId, []];
    missionNamespace setVariable ["FADE_assetObjects_" + _taskId, _assetObjects];
    missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

    private _topoObj = [_center] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _objSituationTaskText = if (_intelFormatter isEqualTo {}) then {
        format [
            "<t align='left' color='#FFD166'>ENEMY</t><br/><t align='left' color='#FFFFFF'>%1 dismounts securing an objective house; patrols in the area.</t><br/><br/><t align='left' color='#FFD166'>FRIENDLY</t><br/><t align='left' color='#FFFFFF'>CTB — task-organized from base.</t>",
            _enemyFactionName
        ]
    } else {
        [
            "AssetRetrieval",
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
    _objSituationTaskText = [_objSituationTaskText] call (missionNamespace getVariable ["FADE_lore_appendSituationHtml", { params ["_s"]; _this select 0 }]);
    private _recoverIntelLine = [_assetName, "#FFFFFF"] call (missionNamespace getVariable ["FADE_smeac_recoverObjectIntelLine", { "" }]);
    if (_recoverIntelLine != "") then { _objSituationTaskText = _objSituationTaskText + "<br/>" + _recoverIntelLine };
    private _objExecutionTaskText = format [
        "<t align='left' color='#C0C0C0'>Move to the marked objective house. Target: %1 — most likely indoors inside a defended building. Clear local OPFOR and use scroll action Pick up on the package. Mission completes when the object is recovered.</t>",
        _assetName
    ];
    private _objMissionDesc = format [
        "Branch: OBJECT RECOVERY — Grid %1 (%2). Recover %3 (most likely indoors inside a defended building).",
        _topoObj select 0,
        _topoObj select 1,
        _assetName
    ];
    [_player, _taskId, _objMissionDesc, "Asset Retrieval", _center, "search", _objSituationTaskText, _objExecutionTaskText] call _fnc_createMissionTask;

    private _markerName = "FADE_asset_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _markerOut = [_taskId, _markerName, _center, _areaRadius, "ColorOrange", "objective", _operationName, -1, -1, [_center]] call FADE_mission_createObjectiveMarker;

    private _grid = mapGridPosition _center;
    private _brief = format ["ASSET RETRIEVAL  -  OBJECT%1%1Objective area (approx.): Grid %2%1%1Recover %3 (most likely indoors inside a defended building). Clear the site and use Pick up on the package to complete.", toString [10], _grid, _assetName] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFCC00'>Branch: Object recovery</t><br/><t color='#FFFFFF'>Target: %2</t><br/><t color='#FFFFFF'>Most likely indoors inside a defended building. Use Pick up when you reach the package.</t>", _grid, _assetName]] call _showAssignedHint;
    [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

    private _arQrfPos = +_center;
    if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
    private _arDetect = (_areaRadius + 120) max 280;

    [
        _taskId, _center, _basePos, _markerName, _player, _assetObjects, _house, _houseBps, _assetIdx,
        _enemyUnitsAsset, _sideEnemy, _baseEnemyClass, _scaleOpforCount, _dryPos, _areaRadius,
        _arQrfPos, _arDetect, _markerOut
    ] spawn {
        params [
            "_taskId", "_center", "_basePos", "_markerName", "_player", "_assetObjects", "_house", "_houseBps", "_assetIdx",
            "_enemyUnitsAsset", "_sideEnemy", "_baseEnemyClass", "_scaleOpforCount", "_dryPos", "_areaRadius",
            "_arQrfPos", "_arDetect", "_markerOut"
        ];
        private _allGroups = [];
        private _vgArHintObjs = [];
        private _garrisonCount = 0;
        private _guardCountSpawned = 0;
        private _houseGarrisonCap = 8;
        private _garrisonCap = 40;
        private _guardCap = 20;
        private _perNearbyBuildingCap = 3;
        for "_i" from 0 to ((count _houseBps) - 1) do {
            if (_garrisonCount >= _houseGarrisonCap) exitWith {};
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
        if (_garrisonCount == 0 && { _houseGarrisonCap > 0 }) then {
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
        private _nearRad = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
        private _nearBldChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
        private _nearSlotP = missionNamespace getVariable ["FADE_vgNearbySlotChance", 0.165];
        private _nearBuildingsFull = (nearestObjects [_center, ["House", "Building"], _nearRad]) select {
            !(_x isEqualTo _house) && { count (_x buildingPos -1) >= 1 } && { [getPosATL _x] call _dryPos }
        };
        if (count _nearBuildingsFull > 16) then {
            _nearBuildingsFull = (_nearBuildingsFull call BIS_fnc_arrayShuffle) select [0, 16];
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
        { if (!isNull _x) then { [_taskId, _x] call FADE_missionEnt_registerObject } } forEach _vgArHintObjs;
        _assetObjects append _vgArHintObjs;
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _allGroups];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, _assetObjects];
        [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
        [_taskId, "AssetRetrieval", _center, _markerOut, _allGroups, "ColorOrange"] call FADE_fieldIntel_startForMission;
        [_taskId, _arQrfPos, _basePos, _enemyUnitsAsset, _allGroups, _arDetect] call FADE_counterAttackStart;
        waitUntil {
            sleep 2;
            if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            false
        };
        [_taskId, _markerName, _player, 45] call FADE_mission_completeCleanup;
        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _assetObjects;
    };
};

