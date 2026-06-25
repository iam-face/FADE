// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_HVT = {
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
    private _hvtMinSlots = 10;
    private _buildRadius = 250;
    private _patrolRadius = 250;
    private _baseDistForComplete = 80;
    private _minDistHVT = 1000;

    private _targetBuilding = objNull;
    private _hvtSearchCenter = if (_fromMapClick && { count _mapAnchor >= 2 }) then { +_mapAnchor } else { +_destPos };
    if (_fromMapClick) then {
        private _buildings = nearestObjects [_hvtSearchCenter, ["House", "Building"], _buildRadius];
        {
            private _bps = _x buildingPos -1;
            if (count _bps >= _hvtMinSlots) exitWith { _targetBuilding = _x };
        } forEach _buildings;
    } else {
        private _attempt = 0;
        while { _attempt < 15 } do {
            _attempt = _attempt + 1;
            if (_attempt > 1) then {
                _destPos = [_minDistHVT] call FADE_findMissionPosUrban;
                if (count _destPos >= 2) then { _destPos = [(_destPos select 0), (_destPos select 1), (_destPos param [2, 0])] };
            };
            if (count _destPos < 2) exitWith {};
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            {
                private _bps = _x buildingPos -1;
                if (count _bps >= _hvtMinSlots) exitWith { _targetBuilding = _x };
            } forEach _buildings;
            if (!isNull _targetBuilding) exitWith {};
        };
    };

    if (isNull _targetBuilding) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No suitable building (10+ positions) in any urban area. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _bpos = _targetBuilding buildingPos -1;
    if (count _bpos < _hvtMinSlots) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Building has insufficient positions.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _officerClasses = _enemyUnits select { ("officer" in (toLower _x)) };
    private _hvtClass = if (count _officerClasses > 0) then { selectRandom _officerClasses } else { if (count _enemyUnits > 0) then { selectRandom _enemyUnits } else { selectRandom _fallbackEnemyInf } };
    private _guardCount = [6 + floor random 4, 2] call _scaleOpforCount;
    private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
    for "_i" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
    private _patrolGroupCount = [1 + floor random 3, 1] call _scaleOpforCount;
    private _patrolSize = [6 + floor random 7, 2] call _scaleOpforCount;

    private _hvtCodename = selectRandom ["Viktor", "Dmitri", "Sergei", "Ivan", "Pavel", "Boris", "Volkov", "Kozlov"];
    private _hvtSlot = 2 + floor random ((count _bpos - 4) max 1);
    private _hvtPos = _bpos select _hvtSlot;
    if (count _hvtPos < 3) then { _hvtPos = [(_hvtPos select 0), (_hvtPos select 1), (_hvtPos param [2, 0])] };
    private _guardIndices = [];
    for "_i" from 0 to (count _bpos - 1) do { if (_i != _hvtSlot) then { _guardIndices pushBack _i } };

    private _hvtGroup = createGroup _sideEnemy;
    // Create HVT at a general building-interior position first, then snap to exact slot
    private _hvt = _hvtGroup createUnit [_hvtClass, getPosATL _targetBuilding, [], 0, "NONE"];
    // Disable movement and pathfinding BEFORE setPos to prevent AI from immediately walking away
    _hvt disableAI "PATH";
    _hvt disableAI "MOVE";
    _hvt allowDamage false;
    _hvt setPos _hvtPos;
    removeAllWeapons _hvt;
    removeAllItems _hvt;
    removeHeadgear _hvt;
    _hvt setIdentity ("FADE_hvt_" + _hvtCodename);
    [_hvt, _hvtPos] spawn {
        params ["_u", "_p"];
        sleep 0.2;
        _u setPos _p;
        removeAllWeapons _u;
        removeAllItems _u;
        removeHeadgear _u;
        private _berets = ["H_Beret_02", "H_Beret_Colonel", "H_Beret_Blk", "H_Beret_ocamo", "H_Beret_red", "H_Beret_gen_F"];
        { if (isClass (configFile >> "CfgWeapons" >> _x)) exitWith { _u addHeadgear _x } } forEach _berets;
        sleep 0.3;
        _u setPos _p;
        _u allowDamage true;
    };
    _hvt setUnitPos "MIDDLE";
    [_hvt, "SIT_LOW", "NONE", { !alive _this }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    private _hvtTypeName = getText (configFile >> "CfgVehicles" >> _hvtClass >> "displayName");
    if (_hvtTypeName == "") then { _hvtTypeName = _hvtClass };

    private _guardGroup = createGroup _sideEnemy;
    for "_i" from 0 to (_guardCount - 1) do {
        if (_i >= count _guardIndices) exitWith {};
        private _idx = _guardIndices select _i;
        private _p = _bpos select _idx;
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
        private _cls = _guardClasses select (_i mod (count _guardClasses));
        private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
        _u setUnitPos "MIDDLE";
        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    };
    [_guardGroup] call FAC_applyEnemyScenarioToGroup;

    private _buildingCenterPatrol = getPosATL _targetBuilding;
    if (count _buildingCenterPatrol < 3) then { _buildingCenterPatrol = [(_buildingCenterPatrol select 0), (_buildingCenterPatrol select 1), 0] };
    private _patrolBaseDist = 150;
    private _patrolDistVariance = 100;

    private _patrolGroups = [];
    for "_pg" from 0 to (_patrolGroupCount - 1) do {
        private _angle = random 360;
        private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
        if (_dist < 50) then { _dist = 50 };
        private _cx = (_buildingCenterPatrol select 0) + _dist * (cos _angle);
        private _cy = (_buildingCenterPatrol select 1) + _dist * (sin _angle);
        private _sp = [_cx, _cy, 0];
        _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
            for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
            private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            for "_w" from 0 to 3 do {
                private _wpAngle = _w * 90;
                private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                if (_wpDist < 50) then { _wpDist = 50 };
                private _wpPos = [(_buildingCenterPatrol select 0) + _wpDist * (cos _wpAngle), (_buildingCenterPatrol select 1) + _wpDist * (sin _wpAngle), 0];
                _wpPos = [[_wpPos, 0, 10, 2, 1, 0.4, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
                if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                    _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
            };
            _patrolGroups pushBack _grp;
        };
    };

    // Additional guards garrisoned in nearby buildings (wide ring; subset of buildings), same pattern as Hostage.
    private _hvtSurroundRadius = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    private _hvtSurroundBChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _hvtVgHintObjs = [];
    private _hvtSurroundFull = (nearestObjects [getPosATL _targetBuilding, ["House", "Building"], _hvtSurroundRadius] select {
        !(_x isEqualTo _targetBuilding) && { count (_x buildingPos -1) >= 1 }
    });
    private _hvtSurroundBuildings = (_hvtSurroundFull select { random 1 < _hvtSurroundBChance });
    if (count _hvtSurroundBuildings == 0 && { count _hvtSurroundFull > 0 }) then { _hvtSurroundBuildings = +_hvtSurroundFull };
    private _vgHvt = missionNamespace getVariable ["FADE_vg_register", {}];
    {
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then {} else {
            private _cnt = ([1 + floor random 3, 1] call _scaleOpforCount) min count _bldPos;
            private _indices = [];
            for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _slotATL = [];
            for "_i" from 0 to (_cnt - 1) do {
                private _p = _bldPos select (_indices select _i);
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                _slotATL pushBack _p;
            };
            if (count _slotATL > 0) then {
                if (!(_vgHvt isEqualTo {})) then {
                    private _st = createHashMap;
                    _st set ["owner", format ["mis:%1", _taskId]];
                    _st set ["groupsRef", _patrolGroups];
                    _st set ["tryBarrel", true];
                    _st set ["barrelMinDistPlayersM", -1];
                    _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                    _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                    private _bCh = getPosATL _bld;
                    if (count _bCh < 3) then { _bCh = [(_bCh select 0), (_bCh select 1), 0] };
                    _st set ["barrelCenter", _bCh];
                    _st set ["barrelsRef", _hvtVgHintObjs];
                    [_bld, _slotATL, +_enemyUnits, _st] call _vgHvt;
                } else {
                    private _surroundGrp = createGroup _sideEnemy;
                    {
                        private _p = +_x;
                        private _cls = selectRandom _enemyUnits;
                        private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    } forEach _slotATL;
                    [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
                    _patrolGroups pushBack _surroundGrp;
                };
            };
        };
    } forEach _hvtSurroundBuildings;

    private _hvtBarrel = objNull;
    private _buildingCenter = getPosATL _targetBuilding;
    if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
    private _barrelPos = [[_buildingCenter, 8, 22, 2, 1, 0.3, 0, [], _buildingCenter], _buildingCenter] call FADE_findSafePosArray;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _hvtBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        _hvtBarrel setPosATL _barrelPos;
    };

    [_player, _taskId, "Eliminate or capture the HVT. Return captive to base to complete.", "HVT", getPosATL _targetBuilding, "target"] call _fnc_createMissionTask;
    private _markerName = "FADE_hvt_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [getPosATL _targetBuilding, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition (getPosATL _targetBuilding);
    private _brief = format ["HVT%1%1Search area (approx.): Grid %2%1Designation: %3  -  %4%1%1Locate and neutralise or capture the high-value target. Secure the area and move the target to extraction as ordered.", toString [10], _grid, _hvtCodename, _hvtTypeName] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>HVT: %2 -- %3</t><br/><br/><t color='#FFFFFF'>Eliminate or capture and return to base.</t>", _grid, _hvtCodename, _hvtTypeName]] call _showAssignedHint;
    [_player, "HVT"] call FADE_notifyOthersMissionStarted;

    private _allGroups = [_hvtGroup, _guardGroup] + _patrolGroups;
    [[_guardGroup] + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    private _hvtObjectivePos = getPosATL _targetBuilding;
    if (count _hvtObjectivePos < 3) then { _hvtObjectivePos = [(_hvtObjectivePos select 0), (_hvtObjectivePos select 1), 0] };
    [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
    if (!isNull _hvtBarrel) then { [_taskId, _hvtBarrel] call FADE_missionEnt_registerObject };
    [_taskId, _hvtObjectivePos, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hvt, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _hvtBarrel, _hvtVgHintObjs] spawn {
        params ["_taskId", "_hvt", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_hvtBarrel", "_hvtVgHintObjs"];
        private _done = false;
        private _hvtFleeing = false;

        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _done = true };
            if (!_done && !alive _hvt) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                _done = true;
            };
            if (!_done && alive _hvt && { _hvt getVariable ["ACE_captives_isHandcuffed", false] || { captive _hvt } }) then {
                if ((_hvt distance _basePos) < _baseDistForComplete) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    _done = true;
                };
            };
            // HVT flee behaviour: triggers once on first COMBAT detection; 70% chance to actually flee
            if (!_done && !_hvtFleeing && alive _hvt) then {
                private _alert = false;
                {
                    if (_alert) exitWith {};
                    { if (alive _x && { behaviour _x == "COMBAT" }) exitWith { _alert = true } } forEach units _x;
                } forEach _allGroups;
                if (_alert) then {
                    _hvtFleeing = true;
                    if (random 1 < 0.7) then {
                        _hvt enableAI "PATH";
                        _hvt switchMove "";
                        (group _hvt) setCombatMode "BLUE";
                        private _fleeDir = random 360;
                        private _fleePos = _hvt getPos [200 + random 150, _fleeDir];
                        _fleePos = [[_fleePos, 0, 25, 3, 1, 0.5, 0, [], _fleePos], _fleePos] call FADE_findSafePosArray;
                        if (_fleePos isEqualType [] && { count _fleePos >= 2 }) then {
                            _hvt doMove _fleePos;
                        };
                    };
                };
            };
            _done
        };

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
    };
};

