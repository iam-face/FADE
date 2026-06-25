// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_CASEVAC = {
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
    private _maxPax = _unitCount max 2;
    private _pickupCount = ((2 + floor random 9) min _maxPax) max 2;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [[_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
    if (count _wpPos < 2) then { _wpPos = _destPos getPos [10, random 360] };
    private _group = [_wpPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group addWaypoint [_wpPos, 0];

    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    private _nStart = count units _group;
    if (_nStart >= 2) then {
        private _kia = (1 + floor random 2) min (_nStart - 1);
        for "_k" from 1 to _kia do {
            private _u = selectRandom units _group;
            if (!isNull _u) then { deleteVehicle _u };
        };
        {
            if (!alive _x) then {} else {
                if (_useACE && _aceHasAddDamage) then {
                    private _p = selectRandom ["Head", "Body", "LeftArm", "RightArm", "LeftLeg", "RightLeg"];
                    [_x, 0.12 + random 0.22, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                    if (_aceHasAddWound) then { [_x, toLower _p, ["Laceration", 1, 0, 0.2]] call ace_medical_fnc_addWound };
                } else {
                    _x setDamage ((damage _x) + 0.15 + random 0.25);
                };
            };
        } forEach units _group;
    };

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

    [_player, _taskId, "CASEVAC: extract casualties and return to base.", "CASEVAC", _destPos, "move", "", format [
        "<t align='left' color='#C0C0C0'>1. Fly to the pickup marker and land.<br/>2. Load all wounded  -  they may need to be carried or assisted aboard.<br/>3. RTB and land at base to complete the mission.</t>"
    ]] call _fnc_createMissionTask;

    private _markerName = "FADE_casevac_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _living = { alive _x } count units _group;
    private _brief = format ["CASEVAC%1%1Pickup (approx.): Grid %2%1%1MedEvac: wounded require immediate lift. Load casualties carefully and RTB according to task instructions.", toString [10], _grid] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>RZ Grid: %1</t><br/><t color='#FFFFFF'>PAX: %2 (wounded)</t><br/><br/><t color='#FFFFFF'>Extract and RTB.</t>", _grid, _living]] call _showAssignedHint;
    [_player, "CASEVAC"] call FADE_notifyOthersMissionStarted;

    private _cvQrfPos = +_destPos;
    if (count _cvQrfPos < 3) then { _cvQrfPos = [(_cvQrfPos select 0), (_cvQrfPos select 1), 0] };
    [_taskId, _enemyGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _cvQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    ["CASEVAC", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        [] call FADE_runTroopTransport;
    };
};

FADE_runMission_CSAR = {
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
    private _pickupClasses = [_friendlyUnits select 0];
    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [[_wpPos, 0, 15, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
    if (!(_wpPos isEqualType [])) then { _wpPos = _destPos getPos [10, random 360] };
    if ((_wpPos isEqualType []) && { count _wpPos < 2 }) then { _wpPos = _destPos getPos [10, random 360] };
    // BIS_fnc_findSafePos can return [x,y] only; setPosATL / createVehicle expect ATL with Z
    if ((_wpPos isEqualType []) && { count _wpPos >= 2 && { count _wpPos < 3 } }) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
    private _friendlyVehicleClasses = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
    private _factionHelis = _friendlyVehicleClasses select {
        _x isKindOf "Helicopter" && { getNumber (configFile >> "CfgVehicles" >> _x >> "isUav") < 1 }
    };
    private _csarWreckClasses = [
        "vn_air_f4b_wreck",
        "vn_air_oh6a_01_wreck",
        "Land_UH1H_Wreck_F",
        "BlackhawkWreck",
        "C130J_wreck_EP1"
    ];
    private _csarWreckOk = _csarWreckClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    if (count _csarWreckOk == 0) then {
        _csarWreckOk = ["Land_Wreck_Heli_Attack_01_F", "Land_Wreck_Heli_Attack_02_F"] select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (count _csarWreckOk == 0) then { _csarWreckOk = ["Land_Wreck_Heli_Attack_01_F"] };
    private _wreck = objNull;
    private _usedFactionHeli = false;
    private _csarAircraftClass = "";
    if (count _factionHelis > 0) then {
        private _heliClass = selectRandom _factionHelis;
        _csarAircraftClass = _heliClass;
        _wreck = createVehicle [_heliClass, _wpPos, [], 0, "NONE"];
        _wreck setPosATL _wpPos;
        _wreck setDir (random 360);
        _wreck setVelocity [0, 0, 0];
        _wreck engineOn false;
        private _sn = surfaceNormal _wpPos;
        if ((vectorMagnitude _sn) > 0.5) then { _wreck setVectorUp _sn };
        _usedFactionHeli = true;
    } else {
        private _wreckClass = selectRandom _csarWreckOk;
        _csarAircraftClass = _wreckClass;
        _wreck = createVehicle [_wreckClass, _wpPos, [], 0, "NONE"];
        _wreck setPosATL _wpPos;
        _wreck setDir (random 360);
    };
    missionNamespace setVariable ["FADE_csarWreck_" + _taskId, _wreck];
    if (!isNull _wreck) then { [_taskId, _wreck] call FADE_missionEnt_registerObject };

    private _survPos = _wreck getPos [10, random 360];
    _survPos = [[_survPos, 0, 8, 2, 1, 0.3, 0, [], _survPos], _survPos] call FADE_findSafePosArray;
    if (!(_survPos isEqualType [])) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos < 2 }) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos >= 2 && { count _survPos < 3 } }) then { _survPos = [(_survPos select 0), (_survPos select 1), 0] };
    private _group = [_survPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    { _x allowDamage false } forEach units _group;
    if (_usedFactionHeli && { !isNull _wreck }) then {
        _wreck setDamage 1;
    };
    private _crashCenter = getPosATL _wreck;
    if (count _crashCenter < 3) then { _crashCenter = [(_crashCenter select 0), (_crashCenter select 1), 0] };
    // Pilot starts moving toward the nearest civ-town center in stealth.
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
    private _nearestTownCenter = +_crashCenter;
    private _bestTownDist = 1e10;
    {
        private _trg = missionNamespace getVariable [_x, objNull];
        if (!isNull _trg) then {
            private _tc = getPosATL _trg;
            if (_tc isEqualType [] && { count _tc >= 2 }) then {
                if (count _tc < 3) then { _tc = [(_tc select 0), (_tc select 1), 0] };
                private _dTown = _tc distance2D _crashCenter;
                if (_dTown < _bestTownDist) then {
                    _bestTownDist = _dTown;
                    _nearestTownCenter = _tc;
                };
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _pilotWp = _group addWaypoint [_nearestTownCenter, 0];
    _pilotWp setWaypointType "MOVE";
    _pilotWp setWaypointSpeed "LIMITED";
    _pilotWp setWaypointCompletionRadius 20;
    _group setBehaviour "STEALTH";
    _group setCombatMode "GREEN";
    _group setSpeedMode "LIMITED";

    // Place two additional KIA friendlies near the wreck for CSAR scene dressing.
    private _csarBodies = [];
    private _kiaClass = _friendlyUnits select 0;
    for "_k" from 0 to 1 do {
        private _kiaPos = _crashCenter getPos [2 + random 8, random 360];
        _kiaPos = [[_kiaPos, 0, 4, 1, 1, 0.3, 0, [], _kiaPos], _kiaPos] call FADE_findSafePosArray;
        if (!(_kiaPos isEqualType []) || { count _kiaPos < 2 }) then { _kiaPos = _crashCenter getPos [2 + random 8, random 360] };
        if (count _kiaPos < 3) then { _kiaPos = [(_kiaPos select 0), (_kiaPos select 1), 0] };
        private _kiaGroup = createGroup [_sideFriendly, true];
        private _kiaUnit = _kiaGroup createUnit [_kiaClass, _kiaPos, [], 0, "NONE"];
        _kiaUnit setPosATL _kiaPos;
        _kiaUnit setDir (random 360);
        _kiaUnit setDamage 1;
        _kiaUnit disableAI "ALL";
        _csarBodies pushBack _kiaUnit;
    };
    missionNamespace setVariable ["FADE_csarBodies_" + _taskId, _csarBodies];

    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    {
        if (_useACE && _aceHasAddDamage) then {
            _x allowDamage true;
            private _p = selectRandom ["Body", "LeftLeg", "RightLeg"];
            [_x, 0.18 + random 0.2, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (_aceHasAddWound) then { [_x, toLower _p, ["VelocityWound", 1, 1, 0.4]] call ace_medical_fnc_addWound };
            _x allowDamage false;
        } else {
            _x allowDamage true;
            _x setDamage (0.25 + random 0.2);
            _x allowDamage false;
        };
    } forEach units _group;

    [_group] spawn {
        params ["_grp"];
        sleep 30;
        if (isNull _grp) exitWith {};
        { if (!isNull _x && { alive _x }) then { _x allowDamage true } } forEach units _grp;
    };

    private _enemyGroups = [];
    if (count _enemyUnits > 0) then {
        private _searchDistances = [750, 1250, 2000];
        {
            private _spawnDist = _x;
            private _grpPos = [];
            for "_try" from 0 to 12 do {
                private _angle = random 360;
                private _candidate = _crashCenter getPos [_spawnDist + (random 80 - 40), _angle];
                _candidate = [[_candidate, 0, 35, 4, 1, 0.4, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
                if (count _candidate < 2) then { _candidate = _crashCenter getPos [_spawnDist, _angle] };
                if (count _candidate < 3) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
                if (
                    (_candidate distance2D _crashCenter) >= (_spawnDist - 150) &&
                    { !(surfaceIsWater _candidate) }
                ) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                for "_fb" from 0 to 18 do {
                    private _fallback = _crashCenter getPos [_spawnDist, random 360];
                    _fallback = [[_fallback, 0, 60, 6, 1, 0.45, 0, [], _fallback], _fallback] call FADE_findSafePosArray;
                    if (count _fallback < 2) then { _fallback = _crashCenter getPos [_spawnDist, random 360] };
                    if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                    if (
                        count _fallback >= 2 &&
                        { !(surfaceIsWater _fallback) } &&
                        { (_fallback distance2D _crashCenter) >= (_spawnDist - 200) }
                    ) exitWith { _grpPos = _fallback };
                };
            };
            if (count _grpPos < 2) then {
                private _fallback = _crashCenter getPos [_spawnDist, random 360];
                if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                if (surfaceIsWater _fallback) then {
                    private _rMin = (_spawnDist - 250) max 80;
                    private _rMax = _spawnDist + 350;
                    _fallback = [[_crashCenter, _rMin, _rMax, 10, 1, 0.5, 0, [], _crashCenter], _crashCenter] call FADE_findSafePosArray;
                    if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                };
                _grpPos = _fallback;
            };
            if (count _grpPos >= 2 && { surfaceIsWater _grpPos }) then {
                private _rMin2 = (_spawnDist - 250) max 80;
                _grpPos = [[_crashCenter, _rMin2, _spawnDist + 350, 10, 1, 0.5, 0, [], _crashCenter], _crashCenter] call FADE_findSafePosArray;
                if (count _grpPos < 3) then { _grpPos = [(_grpPos select 0), (_grpPos select 1), 0] };
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            _grp setCombatMode "GREEN";
            _grp setSpeedMode "LIMITED";
            _grp setFormation "LINE";
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            // 1) Random point within 100 m of crash; 2) same civ-town objective as the survivor's move waypoint
            private _nearCrashWp = +_crashCenter;
            if (count _nearCrashWp < 3) then { _nearCrashWp = [(_nearCrashWp select 0), (_nearCrashWp select 1), 0] };
            for "_wTry" from 0 to 12 do {
                private _r = random 100;
                private _a = random 360;
                private _p = _crashCenter getPos [_r, _a];
                _p = [[_p, 0, 30, 4, 1, 0.45, 0, [], _p], _p] call FADE_findSafePosArray;
                if (!(_p isEqualType []) || { count _p < 2 }) then { _p = _crashCenter getPos [_r * 0.85, _a] };
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                if (!(surfaceIsWater _p) && { (_p distance2D _crashCenter) <= 105 }) exitWith { _nearCrashWp = _p };
            };
            private _townWpPos = +_nearestTownCenter;
            if (count _townWpPos < 3) then { _townWpPos = [(_townWpPos select 0), (_townWpPos select 1), 0] };
            private _wpCrash = _grp addWaypoint [_nearCrashWp, 0];
            _wpCrash setWaypointType "MOVE";
            _wpCrash setWaypointSpeed "LIMITED";
            _wpCrash setWaypointBehaviour "SAFE";
            _wpCrash setWaypointCombatMode "GREEN";
            _wpCrash setWaypointFormation "LINE";
            _wpCrash setWaypointCompletionRadius 35;
            private _wpTown = _grp addWaypoint [_townWpPos, 0];
            _wpTown setWaypointType "MOVE";
            _wpTown setWaypointSpeed "LIMITED";
            _wpTown setWaypointBehaviour "SAFE";
            _wpTown setWaypointCombatMode "GREEN";
            _wpTown setWaypointFormation "LINE";
            _wpTown setWaypointCompletionRadius 25;
            _enemyGroups pushBack _grp;
        } forEach _searchDistances;
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
    };

    [_player, _taskId, "CSAR: recover the survivor at the crash site and RTB.", "CSAR", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_csar_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _aircraftCfg = configFile >> "CfgVehicles" >> _csarAircraftClass;
    private _aircraftName = if (isClass _aircraftCfg) then { getText (_aircraftCfg >> "displayName") } else { _csarAircraftClass };
    if (_aircraftName == "") then { _aircraftName = _csarAircraftClass };
    private _brief = format [
        "CSAR%1%1Aircraft: %2%1Crash / survivor area (approx.): Grid %3%1%1Search for and recover isolated personnel from the crash site. Survivors may have fled toward nearby towns seeking assistance  -  widen your search beyond the wreck. When you are close, survivors may mark their position with smoke.%1%1Extract survivors as directed; follow Tasks for approach and RTB procedures.",
        toString [10],
        _aircraftName,
        _grid
    ] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>CSAR Grid: %1</t><br/><br/><t color='#FFFFFF'>Aircraft: %2</t><br/><t color='#FFFFFF'>Survivor may not be at the wreck  -  search nearby towns.</t>", _grid, _aircraftName]] call _showAssignedHint;
    [_player, "CSAR"] call FADE_notifyOthersMissionStarted;

    [_taskId, _enemyGroups] call FADE_missionEnt_bindGroups;
    [_taskId, _crashCenter, _basePos, _enemyUnits, _enemyGroups, 500] call FADE_counterAttackStart;

    // 1 km: survivor sideChat + grid; 500 m: green smoke.
    // After smoke the survivor freezes in place, drops patrol waypoints, and tries to board nearby player vehicles.
    [_group, _taskId] spawn {
        params ["_group", "_taskId"];
        private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
        private _didRadio1k = false;
        private _didSmoke500 = false;
        private _holdActive = false;
        while {
            !isNull _group && { count units _group > 0 } &&
            { !((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]) }
        } do {
            sleep 3;
            private _ldr = leader _group;
            if (isNull _ldr || !alive _ldr) exitWith {};
            private _minD = 1e10;
            {
                if (side _x == _sf && { isPlayer _x } && { alive _x }) then {
                    private _d = _x distance _ldr;
                    if (_d < _minD) then { _minD = _d };
                };
            } forEach allPlayers;
            if (_minD < 1e10) then {
                private _posLdr = getPosATL _ldr;
                if (!_didRadio1k && { _minD <= 1000 }) then {
                    _didRadio1k = true;
                    private _cs = _group getVariable ["FADE_callsign", "Survivor"];
                    private _grid = mapGridPosition _posLdr;
                    [_ldr, format ["This is %1. Mayday  -  holding near Grid %2. Need immediate pickup. Over.", _cs, _grid]] call FADE_aiSideChat;
                };
                if (!_didSmoke500 && { _minD <= 500 }) then {
                    _didSmoke500 = true;
                    "SmokeShellGreen" createVehicle _posLdr;
                    private _cs2 = _group getVariable ["FADE_callsign", "Survivor"];
                    [_ldr, format ["This is %1. Marking position with green smoke. Over.", _cs2]] call FADE_aiSideChat;

                    // Stop roaming once pickup signal is out.
                    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
                    _group setBehaviour "AWARE";
                    _group setCombatMode "GREEN";
                    _group setSpeedMode "LIMITED";
                    private _holdWp = _group addWaypoint [_posLdr, 0];
                    _holdWp setWaypointType "HOLD";
                    _holdWp setWaypointCompletionRadius 5;
                    _holdWp setWaypointSpeed "LIMITED";
                    _holdActive = true;
                };

                if (_holdActive) then {
                    private _survivor = _ldr;
                    if (!isNull _survivor && { alive _survivor } && { vehicle _survivor == _survivor }) then {
                        private _nearestVeh = objNull;
                        private _nearestDist = 1e10;
                        {
                            if (side _x == _sf && { isPlayer _x } && { alive _x }) then {
                                private _veh = vehicle _x;
                                if (_veh != _x && { alive _veh } && { canMove _veh }) then {
                                    private _dVeh = _survivor distance _veh;
                                    if (_dVeh < _nearestDist) then {
                                        _nearestVeh = _veh;
                                        _nearestDist = _dVeh;
                                    };
                                };
                            };
                        } forEach allPlayers;

                        if (!isNull _nearestVeh && { _nearestDist <= 80 }) then {
                            private _hasSeat = (_nearestVeh emptyPositions "cargo") > 0 || { (_nearestVeh emptyPositions "turret") > 0 } || { (_nearestVeh emptyPositions "gunner") > 0 };
                            if (_hasSeat) then {
                                _survivor assignAsCargo _nearestVeh;
                                [_survivor] orderGetIn true;
                            };
                        };
                    };
                };
            };
        };
    };

    ["CSAR", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        [] call FADE_runTroopTransport;
    };
};

