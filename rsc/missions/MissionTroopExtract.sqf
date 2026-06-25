// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_TroopExtract = {
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
    if (_fromMapClick && { [_mapAnchor] call FADE_fnc_isValidMapClickPos }) then {
        _destPos = +_mapAnchor;
        if (count _destPos < 3) then { _destPos set [2, 0] };
    };
    // Pickup group: 2-10 units regardless of player's vehicle
    private _pickupCount = 2 + floor random 9;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [[_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
    if (count _wpPos < 2) then { _wpPos = _destPos getPos [10, random 360] };
    private _group = [_wpPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group addWaypoint [_wpPos, 0];

    private _enemyGroups = [];
    if (random 1 < 0.5) then {
        private _numEnemyGroups = [1 + floor random 5, 1] call _scaleOpforCount;
        private _minDistFromBase = 1000;
        for "_g" from 0 to (_numEnemyGroups - 1) do {
            private _grpPos = [];
            for "_try" from 0 to 10 do {
                private _angle = random 360;
                private _dist = 500 + random 1500;
                private _candidate = _destPos getPos [_dist, _angle];
                _candidate = [[_candidate, 0, 30, 3, 1, 0.4, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
                if (count _candidate < 2) then { _candidate = _destPos getPos [_dist, _angle] };
                if ((_candidate distance _basePos) >= _minDistFromBase) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                private _dirAwayFromBase = _destPos getDir _basePos;
                _grpPos = _destPos getPos [800, _dirAwayFromBase + 180];
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "AWARE";
            _grp setCombatMode "RED";
            _grp addWaypoint [_destPos, 0];
            _enemyGroups pushBack _grp;
        };
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
        _group setBehaviour "COMBAT";
        _group setFormation "DIAMOND";
    } else {
        _group setBehaviour "SAFE";
        _group setCombatMode "GREEN";
        _group setFormation "STAG COLUMN";
    };

    [_player, _taskId, "Extract the squad and return them to base.", "Troop Extract", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_extract_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _enemyLikely = (count _enemyGroups) > 0;
    private _threatBrief = if (_enemyLikely) then { "THREAT: enemy party likely in area" } else { "THREAT: low enemy presence expected" };
    private _threatHint = if (_enemyLikely) then { "Enemy activity likely near pickup." } else { "Low enemy activity expected near pickup." };
    private _brief = format ["TROOP EXTRACT%1%1Pickup (approx.): Grid %2%1%1Recover the squad and return to base. Expect the threat level shown on the task  -  prepare for contact during pickup and RTB.", toString [10], _grid] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>RZ Grid: %1</t><br/><t color='#FFFFFF'>PAX: %2 personnel</t><br/><t color='#FFFFFF'>%3</t><br/><br/><t color='#FFFFFF'>Proceed to pickup zone. Land to load squad. RTB once loaded.</t>", _grid, _pickupCount, _threatHint]] call _showAssignedHint;
    [_player, "Troop Extract"] call FADE_notifyOthersMissionStarted;

    private _teQrfPos = +_destPos;
    if (count _teQrfPos < 3) then { _teQrfPos = [(_teQrfPos select 0), (_teQrfPos select 1), 0] };
    [_taskId, _enemyGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _teQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        [] call FADE_runTroopTransport;
    };
};

