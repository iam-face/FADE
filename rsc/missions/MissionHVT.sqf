// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_HVT = {
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
    private _hvtMinSlots = 10;
    private _buildRadius = 450;
    private _patrolRadius = missionNamespace getVariable ["FADE_hvtSearchRadiusM", 125];
    private _baseDistForComplete = 80;
    private _minDistHVT = 1000;

    private _hvtSearchCenters = [];
    if (_fromMapClick) then {
        if (count _mapAnchor >= 2) then { _hvtSearchCenters pushBack +_mapAnchor };
        if (count _destPos >= 2) then {
            private _dup = _hvtSearchCenters findIf { (_x distance2D _destPos) < 25 };
            if (_dup < 0) then { _hvtSearchCenters pushBack +_destPos };
        };
    } else {
        if (count _destPos >= 2) then { _hvtSearchCenters pushBack +_destPos };
    };
    private _targetBuilding = [
        _fromMapClick,
        _hvtSearchCenters,
        _destPos,
        _buildRadius,
        _hvtMinSlots,
        25,
        _minDistHVT,
        FADE_findMissionPosUrban
    ] call FADE_objective_findBuildingForMission;

    if (isNull _targetBuilding) exitWith {
        [_player] call FADE_clearActiveMission;
        private _mapSuffix = if (_fromMapClick) then {
            " NO SUITABLE BUILDING NEAR THE NEAREST SETTLEMENT TO YOUR CLICK  -  TRY ANOTHER AREA OR USE RANDOM."
        } else { "" };
        [_player, "MISSION ERROR", format ["No suitable building (10+ positions) in any urban area.%1", _mapSuffix]] call FADE_missionErrorHint;
    };

    private _patrolGroupCount = [1 + floor random 3, 1] call _scaleOpforCount;
    private _diffMul = _opforCountFactor max 1;
    private _hvtCodename = [] call FADE_pickHvtCodename;
    private _bpos = _targetBuilding buildingPos -1;
    private _hvtSlot = 2 + floor random ((count _bpos - 4) max 1);
    private _hvtData = [_targetBuilding, _hvtSlot, _sideEnemy, _enemyUnits, _hvtCodename, true] call FADE_objective_spawnHVTInBuilding;
    _hvtData params ["_hvt", "_hvtGroup", "_hvtCodename", "_hvtClass"];
    private _hvtTypeName = getText (configFile >> "CfgVehicles" >> _hvtClass >> "displayName");
    if (_hvtTypeName == "") then { _hvtTypeName = _hvtClass };

    private _guardCount = [6 + floor random 4, 2] call _scaleOpforCount;
    private _guardGroup = [_targetBuilding, _hvtSlot, _guardCount, _sideEnemy, _enemyUnits] call FADE_objective_garrisonBuilding;
    private _buildingCenterPatrol = getPosATL _targetBuilding;
    private _hvtSurvey = [_hvtObjectivePos, _patrolRadius * 2] call FADE_aoSurvey_build;
    private _patrolGroups = [
        _buildingCenterPatrol,
        _patrolRadius,
        _patrolGroupCount,
        _sideEnemy,
        _enemyUnits,
        _diffMul,
        _hvtSurvey
    ] call FADE_objective_spawnPatrols;

    private _hvtObjectivePos = getPosATL _targetBuilding;
    if (count _hvtObjectivePos < 3) then { _hvtObjectivePos = [(_hvtObjectivePos select 0), (_hvtObjectivePos select 1), 0] };

    private _areaGroups = [];
    [_hvtObjectivePos, [_targetBuilding], _sideEnemy, _enemyUnits, _diffMul, _areaGroups] call FADE_objective_spawnImmediateAreaGarrison;

    private _hvtVgHintObjs = [];
    private _innerGarRad = missionNamespace getVariable ["FADE_raidTargetImmediateGarrisonRadiusM", 250];
    private _nearGarRad = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    [
        _taskId, _targetBuilding, _buildingCenterPatrol, _areaGroups + _patrolGroups, _hvtVgHintObjs, _enemyUnits, _diffMul,
        _nearGarRad, -1, 1, [_targetBuilding], _hvtObjectivePos, _innerGarRad
    ] call FADE_objective_registerNearbyGarrisons;

    private _hvtBarrel = objNull;
    private _buildingCenter = getPosATL _targetBuilding;
    if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
    private _barrelPos = [_buildingCenter] call FADE_findOutdoorHintPos;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _hvtBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        _hvtBarrel setPosATL _barrelPos;
    };

    private _hvtTaskLine = format [
        "Eliminate or capture HVT %1 (%2). Return captive to base to complete.",
        _hvtCodename,
        _hvtTypeName
    ];
    [_player, _taskId, _hvtTaskLine, "HVT", getPosATL _targetBuilding, "target"] call _fnc_createMissionTask;
    private _markerName = "FADE_hvt_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _markerOut = [_taskId, _markerName, _hvtObjectivePos, _patrolRadius, _markerEnemy, "objective", _operationName, -1, -1, [_hvtObjectivePos]] call FADE_mission_createObjectiveMarker;

    private _grid = mapGridPosition (getPosATL _targetBuilding);
    private _brief = format ["HVT%1%1Search area (approx.): Grid %2%1Designation: %3  -  %4%1%1Find the HVT. Kill or capture. If captured, get them back near base.", toString [10], _grid, _hvtCodename, _hvtTypeName] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>HVT: %2 -- %3</t><br/><br/><t color='#FFFFFF'>Eliminate or capture and return to base.</t>", _grid, _hvtCodename, _hvtTypeName]] call _showAssignedHint;
    [_player, "HVT"] call FADE_notifyOthersMissionStarted;

    private _allGroups = [_hvtGroup, _guardGroup] + _areaGroups + _patrolGroups;
    [[_guardGroup] + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    [_taskId, "HVT", _hvtObjectivePos, _markerOut, _allGroups, _markerEnemy] call FADE_fieldIntel_startForMission;

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

        [_taskId, _markerName, _player, 60] call FADE_mission_completeCleanup;
    };
};

