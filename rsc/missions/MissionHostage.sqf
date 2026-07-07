// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_Hostage = {
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
    private _buildRadius = 450;
    private _minSlotsPerBuilding = 5;
    private _minSuitableBuildings = 2;
    private _baseDistForComplete = 100;
    private _minDistHostage = 1000;
    private _maxAttempts = 50;

    private _hostageSearchCenter = if (_fromMapClick && { count _mapAnchor >= 2 }) then { +_mapAnchor } else { +_destPos };
    private _suitableBuildings = [
        _fromMapClick,
        _hostageSearchCenter,
        _destPos,
        _buildRadius,
        _minSlotsPerBuilding,
        _minSuitableBuildings,
        _maxAttempts,
        _minDistHostage,
        FADE_findMissionPosUrbanNearCenter
    ] call FADE_objective_findBuildingsWithMinSlots;

    if (count _suitableBuildings < _minSuitableBuildings) exitWith {
        [_player] call FADE_clearActiveMission;
        private _mapSuffix = if (_fromMapClick) then {
            " NO SUITABLE BUILDINGS NEAR YOUR MAP CLICK  -  TRY A BUILT-UP AREA OR USE RANDOM."
        } else { "" };
        [_player, "MISSION ERROR", format [
            "No urban area with at least 2 suitable buildings (5+ positions each) near a civ zone.%1",
            _mapSuffix
        ]] call FADE_missionErrorHint;
    };

    private _hostageCount = 1 + floor random 3;
    private _hostageIdPool = +(missionNamespace getVariable ["FADE_hostageIdentities", ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"]]);
    if (_hostageIdPool isEqualTo []) then { _hostageIdPool = ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"] };
    private _hostageIdOrder = _hostageIdPool call BIS_fnc_arrayShuffle;
    private _diffMul = _opforCountFactor max 1;

    private _hostages = [];
    private _hostageNames = [];
    private _guardGroups = [];
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
        private _startIdx = _nextSlotByBuilding select _buildingIdx;
        _nextSlotByBuilding set [_buildingIdx, _startIdx + _minSlotsPerBuilding];

        private _hostageIdx = _startIdx + floor ((_minSlotsPerBuilding - 1) / 2);
        private _idKey = if (_h < count _hostageIdOrder) then { _hostageIdOrder select _h } else { selectRandom _hostageIdPool };
        private _hn = [_hostageGroup, _building, _hostageIdx, _idKey] call FADE_objective_addHostageToGroup;
        _hostages pushBack (_hn select 0);
        _hostageNames pushBack (_hn select 1);

        private _guardCount = [3 + floor random 4, 1] call _scaleOpforCount;
        private _guardSlotIndices = [];
        for "_i" from 0 to (_minSlotsPerBuilding - 1) do {
            if (_startIdx + _i != _hostageIdx) then { _guardSlotIndices pushBack (_startIdx + _i) };
        };
        _guardSlotIndices = _guardSlotIndices select [0, _guardCount min count _guardSlotIndices];
        private _guardGroup = [_building, _guardSlotIndices, _sideEnemy, _enemyUnits] call FADE_objective_garrisonBuildingSlots;
        if (!isNull _guardGroup) then { _guardGroups pushBack _guardGroup };
    };

    if (count _hostages == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "Could not place hostages."] call FADE_missionErrorHint;
    };

    private _missionCenter = getPosATL (_buildingsUsed select 0);
    if (count _missionCenter < 3) then { _missionCenter = [(_missionCenter select 0), (_missionCenter select 1), 0] };

    private _hoVgHintObjs = [];
    [_taskId, objNull, _missionCenter, _guardGroups, _hoVgHintObjs, _enemyUnits, _diffMul, -1, -1, -1, _buildingsUsed] call FADE_objective_registerNearbyGarrisons;

    private _patrolGroups = [_buildingsUsed, _sideEnemy, _enemyUnits, _scaleOpforCount] call FADE_objective_spawnPatrolsPerBuilding;

    private _hostageNamesLine = _hostageNames joinString "; ";
    private _taskHostageLine = format [
        "Rescue hostages: %1. Return all alive to base (within 100 m). Excessive casualties among hostages will abort the task.",
        _hostageNamesLine
    ];
    [_player, _taskId, _taskHostageLine, "Hostage", _missionCenter, "run"] call _fnc_createMissionTask;
    private _markerName = "FADE_hostage_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _searchRadius = missionNamespace getVariable ["FADE_hostageSearchRadiusM", 125];
    private _hoBldPos = _buildingsUsed apply {
        private _p = getPosATL _x;
        if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
    };
    private _hoAnchor = [_hoBldPos] call FADE_mission_positionsCentroid;
    [_taskId, _markerName, _hoAnchor, _searchRadius, "ColorCIV", "mil_objective", _operationName, -1, -1, _hoBldPos] call FADE_mission_createObjectiveMarker;

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
                [_player, "Too many hostages lost."] call FADE_missionFailHint;
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

        [_taskId, _markerName, _player, 60] call FADE_mission_completeCleanup;
    };
};
