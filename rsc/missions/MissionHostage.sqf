// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_Hostage = {
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
    private _buildRadius = 450;
    private _minSlotsPerBuilding = 5;
    private _minSuitableBuildings = 2;
    private _baseDistForComplete = 100;
    private _minDistHostage = 1000;
    private _maxAttempts = 50;

    private _suitableBuildings = [];
    private _hostageSearchCenter = if (_fromMapClick && { count _mapAnchor >= 2 }) then { +_mapAnchor } else { +_destPos };
    if (_fromMapClick) then {
        private _buildings = nearestObjects [_hostageSearchCenter, ["House", "Building"], _buildRadius];
        _suitableBuildings = _buildings select { count (_x buildingPos -1) >= _minSlotsPerBuilding };
    } else {
        private _attempt = 0;
        while { _attempt < _maxAttempts && { count _suitableBuildings < _minSuitableBuildings } } do {
            _attempt = _attempt + 1;
            _destPos = [_minDistHostage] call FADE_findMissionPosUrbanNearCenter;
            if (count _destPos >= 2) then {
                private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
                _suitableBuildings = _buildings select { count (_x buildingPos -1) >= _minSlotsPerBuilding };
            };
        };
    };
    if (count _suitableBuildings < _minSuitableBuildings) exitWith {
        [_player] call FADE_clearActiveMission;
        private _mapSuffix = if (_fromMapClick) then {
            " NO SUITABLE BUILDINGS NEAR YOUR MAP CLICK  -  TRY A BUILT-UP AREA OR USE RANDOM."
        } else { "" };
        [format [
            "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No urban area with at least 2 suitable buildings (5+ positions each) near a civ zone.%1</t>",
            _mapSuffix
        ]] remoteExec ["FADE_showMissionHint", _player];
    };

    private _hostageCount = 1 + floor random 3;
    private _civClasses = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"]];
    if (_civClasses isEqualTo []) then { _civClasses = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };

    private _hostageIdPool = +(missionNamespace getVariable ["FADE_hostageIdentities", ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"]]);
    if (_hostageIdPool isEqualTo []) then { _hostageIdPool = ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"] };
    private _hostageIdOrder = _hostageIdPool call BIS_fnc_arrayShuffle;

    private _hostages = [];
    private _hostageNames = [];
    private _guardGroups = [];
    private _patrolGroups = [];
    private _buildingsUsed = [];
    private _hostageGroup = createGroup CIVILIAN;
    private _nextSlotByBuilding = [];
    for "_i" from 0 to (count _suitableBuildings - 1) do { _nextSlotByBuilding pushBack 0 };

    for "_h" from 0 to (_hostageCount - 1) do {
        private _buildingIdx = -1;
        for "_b" from 0 to (count _suitableBuildings - 1) do {
            if ((_nextSlotByBuilding select _b) + _minSlotsPerBuilding <= count ((_suitableBuildings select _b) buildingPos -1)) exitWith { _buildingIdx = _b };
        };
        if (_buildingIdx < 0) exitWith {};
        private _building = _suitableBuildings select _buildingIdx;
        if (!(_building in _buildingsUsed)) then { _buildingsUsed pushBack _building };
        private _bpos = _building buildingPos -1;
        private _startIdx = _nextSlotByBuilding select _buildingIdx;
        _nextSlotByBuilding set [_buildingIdx, _startIdx + _minSlotsPerBuilding];

        private _guardCount = [3 + floor random 4, 1] call _scaleOpforCount;
        private _midOffset = floor ((_minSlotsPerBuilding - 1) / 2);
        private _hostageIdx = _startIdx + _midOffset;
        private _hostagePos = _bpos select _hostageIdx;
        if (count _hostagePos < 3) then { _hostagePos = [(_hostagePos select 0), (_hostagePos select 1), (_hostagePos param [2, 0])] };

        private _civClass = selectRandom _civClasses;
        private _hostage = _hostageGroup createUnit [_civClass, _hostagePos, [], 0, "NONE"];
        private _idKey = if (_h < count _hostageIdOrder) then { _hostageIdOrder select _h } else { selectRandom _hostageIdPool };
        _hostage setIdentity _idKey;
        removeAllWeapons _hostage;
        removeAllItems _hostage;
        removeHeadgear _hostage;
        removeGoggles _hostage;
        _hostage addGoggles "G_Blindfold_01_black_F";
        _hostage disableAI "PATH";
        _hostage setUnitPos "MIDDLE";
        _hostage switchMove "Acts_ExecutionVictim_Loop";
        _hostages pushBack _hostage;
        _hostageNames pushBack name _hostage;

        private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
        for "_g" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
        private _guardGroup = createGroup _sideEnemy;
        private _guardSlotIndices = [];
        for "_i" from 0 to (_minSlotsPerBuilding - 1) do {
            if (_startIdx + _i != _hostageIdx) then { _guardSlotIndices pushBack (_startIdx + _i) };
        };
        for "_i" from 0 to (_guardCount - 1) do {
            if (_i >= count _guardSlotIndices) exitWith {};
            private _idx = _guardSlotIndices select _i;
            private _p = _bpos select _idx;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
            private _cls = _guardClasses select (_i mod (count _guardClasses));
            private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
        };
        [_guardGroup] call FAC_applyEnemyScenarioToGroup;
        _guardGroups pushBack _guardGroup;
    };

    if (count _hostages == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place hostages.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Additional guards in surrounding buildings (wide ring; subset of buildings), 1â€“3 units per building
    private _surroundRadius = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    private _surroundBChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _hoVgHintObjs = [];
    private _surroundFull = (nearestObjects [_destPos, ["House", "Building"], _surroundRadius] select { !(_x in _buildingsUsed) && { count (_x buildingPos -1) >= 1 } });
    private _surroundBuildings = (_surroundFull select { random 1 < _surroundBChance });
    if (count _surroundBuildings == 0 && { count _surroundFull > 0 }) then { _surroundBuildings = +_surroundFull };
    private _vgHo = missionNamespace getVariable ["FADE_vg_register", {}];
    {
        private _bld = _x;
        private _bpos = _bld buildingPos -1;
        if (_bpos isEqualTo []) then {} else {
            private _count = [1 + floor random 3, 1] call _scaleOpforCount;
            _count = _count min count _bpos;
            private _indices = [];
            for "_i" from 0 to (count _bpos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _guardClasses = (_enemyUnits select [0, _count min count _enemyUnits]);
            for "_k" from (count _guardClasses) to (_count - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
            private _slotATL = [];
            private _clsPerSlot = [];
            for "_i" from 0 to (_count - 1) do {
                private _idx = _indices select _i;
                private _p = _bpos select _idx;
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                _slotATL pushBack _p;
                _clsPerSlot pushBack (_guardClasses select (_i mod (count _guardClasses)));
            };
            if (count _slotATL > 0) then {
                if (!(_vgHo isEqualTo {})) then {
                    private _st = createHashMap;
                    _st set ["owner", format ["mis:%1", _taskId]];
                    _st set ["groupsRef", _guardGroups];
                    _st set ["tryBarrel", true];
                    _st set ["barrelMinDistPlayersM", -1];
                    _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                    _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                    private _bCh = getPosATL _bld;
                    if (count _bCh < 3) then { _bCh = [(_bCh select 0), (_bCh select 1), 0] };
                    _st set ["barrelCenter", _bCh];
                    _st set ["barrelsRef", _hoVgHintObjs];
                    [_bld, _slotATL, _clsPerSlot, _st] call _vgHo;
                } else {
                    private _surroundGrp = createGroup _sideEnemy;
                    for "_i" from 0 to (_count - 1) do {
                        private _p = _slotATL select _i;
                        private _cls = _clsPerSlot select _i;
                        private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                        _u setUnitPos "MIDDLE";
                        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    };
                    [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
                    _guardGroups pushBack _surroundGrp;
                };
            };
        };
    } forEach _surroundBuildings;

    private _patrolBaseDist = 80;
    private _patrolDistVariance = 40;
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        for "_pg" from 0 to 1 do {
            private _angle = random 360;
            private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
            if (_dist < 40) then { _dist = 40 };
            private _cx = (_buildingCenter select 0) + _dist * (cos _angle);
            private _cy = (_buildingCenter select 1) + _dist * (sin _angle);
            private _sp = [_cx, _cy, 0];
            _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _patrolSize = [2 + floor random 3, 1] call _scaleOpforCount;
                private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
                for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
                private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _wpAngle = _w * 90;
                    private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                    if (_wpDist < 40) then { _wpDist = 40 };
                    private _wpPos = [(_buildingCenter select 0) + _wpDist * (cos _wpAngle), (_buildingCenter select 1) + _wpDist * (sin _wpAngle), 0];
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
    } forEach _buildingsUsed;

    private _missionCenter = getPosATL (_buildingsUsed select 0);
    if (count _missionCenter < 3) then { _missionCenter = [(_missionCenter select 0), (_missionCenter select 1), 0] };

    private _hostageNamesLine = _hostageNames joinString "; ";
    private _taskHostageLine = format ["Rescue: %1. Return all alive to base (within 100 m). Mission fails if more than half die.", _hostageNamesLine];
    [_player, _taskId, _taskHostageLine, "Hostage", _missionCenter, "run"] call _fnc_createMissionTask;
    private _markerName = "FADE_hostage_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_missionCenter, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorCIV";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _missionCenter;
    private _brief = format ["HOSTAGE%1%1Incident area (approx.): Grid %2%1%1Rescue civilians held by hostiles. Prioritise civilian safety and follow the task's ROE and handling procedures for recovered persons.", toString [10], _grid] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>%2 hostage(s): %3</t><br/><br/><t color='#FFFFFF'>Rescue and return all alive to base (within 100 m).</t>", _grid, count _hostages, _hostageNamesLine]] call _showAssignedHint;
    [_player, "Hostage"] call FADE_notifyOthersMissionStarted;

    private _initialHostageCount = count _hostages;
    private _allGroups = [_hostageGroup] + _guardGroups + _patrolGroups;
    [_guardGroups + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    [_taskId, _allGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _missionCenter, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hostages, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _initialHostageCount, _hoVgHintObjs] spawn {
        params ["_taskId", "_hostages", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_initialHostageCount", "_hoVgHintObjs"];
        private _done = false;

        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _done = true };
            private _alive = _hostages select { alive _x };
            private _aliveCount = count _alive;
            if (!_done && _aliveCount < (ceil (_initialHostageCount / 2))) then {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Too many hostages lost.</t>"] remoteExec ["FADE_showMissionHint", _player];
                _done = true;
            };
            if (!_done && _aliveCount > 0) then {
                private _allAtBase = (_alive findIf { (_x distance _basePos) >= _baseDistForComplete }) == -1;
                if (_allAtBase) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    _done = true;
                };
            };
            _done
        };

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
    };
};

