// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_InterceptConvoy = {
    private _missionType = missionNamespace getVariable ["FADE_missionRun_missionType", ""];
    private _destPos = missionNamespace getVariable ["FADE_missionRun_destPos", [0,0,0]];
    private _player = missionNamespace getVariable ["FADE_missionRun_player", objNull];
    private _evadeePlayers = missionNamespace getVariable ["FADE_missionRun_evadeePlayers", []];
    private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
    private _mapAnchor = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
    private _mapPickResolvedR = missionNamespace getVariable ["FADE_missionRun_mapPickResolvedRadius", -1];
    private _convoyEndRaw = missionNamespace getVariable ["FADE_missionRun_convoyEndRaw", []];
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
    private _efConv = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _convoyVehicles = [_efConv] call FADE_getEnemyVehiclesForFaction;
    if (_convoyVehicles isEqualTo []) then {
        _convoyVehicles = +(missionNamespace getVariable ["FADE_enemyVehicles", []]);
    };
    private _enemyUnitsConv = +_enemyUnits;
    _enemyUnitsConv = [_enemyUnitsConv] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsConv == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured for convoy crew.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _soft = [];
    private _armored = [];
    {
        if (_x isKindOf "Air" || { _x isKindOf "Ship" } || { _x isKindOf "StaticWeapon" }) then {} else {
            if (_x isKindOf "Tank" || { _x isKindOf "Wheeled_APC_F" }) then { _armored pushBack _x } else { _soft pushBack _x };
        };
    } forEach _convoyVehicles;
    if (count _soft == 0 && { count _armored == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Enemy faction has no land vehicles. Choose a faction with cars/trucks or light armour.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (isNil "FADE_interceptConvoyRoadRoute") exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Convoy route helper not loaded.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _route = if ([_convoyEndRaw] call FADE_fnc_isValidMapClickPos) then {
        [_basePos, -1, _mapAnchor, _mapPickResolvedR, _convoyEndRaw] call FADE_interceptConvoyRoadRoute
    } else {
        if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
            [_basePos, -1, _mapAnchor, _mapPickResolvedR] call FADE_interceptConvoyRoadRoute
        } else {
            [_basePos] call FADE_interceptConvoyRoadRoute
        };
    };
    if (_route isEqualTo []) exitWith {
        [_player] call FADE_clearActiveMission;
        private _msg = if ([_convoyEndRaw] call FADE_fnc_isValidMapClickPos) then {
            "Could not build a convoy route from your start and end clicks (need roads near each point). Try again."
        } else {
            format ["Could not find a suitable convoy route (roads at least %1 m apart). Try again.", round (missionNamespace getVariable ["FADE_convoyMinRouteM", 5000])]
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1</t>", _msg]] remoteExec ["FADE_showMissionHint", _player];
    };
    private _startPos = _route select 0;
    private _endPos = _route select 1;
    if (count _startPos < 3) then { _startPos = [(_startPos select 0), (_startPos select 1), 0] };
    if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };
    private _routeWaypoints = if (isNil "FADE_interceptConvoyRouteWaypoints") then {
        [_startPos, _endPos]
    } else {
        [_startPos, _endPos, 9] call FADE_interceptConvoyRouteWaypoints
    };
    if (_routeWaypoints isEqualTo []) then { _routeWaypoints = [_startPos, _endPos] };
    _startPos = _routeWaypoints select 0;
    _endPos = _routeWaypoints select ((count _routeWaypoints) - 1);
    private _applyConvoyLeadRoute = {
        params ["_grp", "_wps"];
        if (isNull _grp || { _wps isEqualTo [] } || { count _wps < 2 }) exitWith { objNull };
        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
        _grp setFormation "COLUMN";
        _grp setBehaviour "SAFE";
        _grp setSpeedMode "NORMAL";
        private _lastWp = objNull;
        for "_wi" from 1 to ((count _wps) - 1) do {
            private _wpPos = _wps select _wi;
            private _wp = _grp addWaypoint [_wpPos, 20];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "NORMAL";
            _lastWp = _wp;
        };
        _lastWp
    };
    private _convoySize = [3 + floor random 4, 2] call _scaleOpforCount;
    private _numArmored = (([floor random 3, 0] call _scaleOpforCount) min 2) min _convoySize;
    private _vehicleClasses = [];
    for "_v" from 0 to (_convoySize - 1) do {
        if (_v < _numArmored && { count _armored > 0 }) then {
            _vehicleClasses pushBack (selectRandom _armored);
        } else {
            if (count _soft > 0) then { _vehicleClasses pushBack (selectRandom _soft) } else { _vehicleClasses pushBack (selectRandom _armored) };
        };
    };
    private _convoyVehicleGroups = [];
    private _convoyVehiclesSpawned = [];
    private _convoySpawnEntries = [];
    private _cargoGroups = [];
    private _convoyWp = objNull;
    private _leadGrp = grpNull;
    private _dir = [_startPos, _endPos] call BIS_fnc_dirTo;
    private _setupConvoyFollow = {
        params ["_vehGrp", "_leadVehicle"];
        if (isNull _vehGrp || { isNull _leadVehicle }) exitWith {};
        while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
        _vehGrp setBehaviour "SAFE";
        _vehGrp setSpeedMode "NORMAL";
        private _wpF = _vehGrp addWaypoint [getPosATL _leadVehicle, 20];
        _wpF setWaypointType "FOLLOW";
        _wpF setWaypointSpeed "NORMAL";
        _wpF waypointAttachVehicle [_leadVehicle, _vehGrp];
    };
    private _findConvoySafeSpawn = {
        params ["_desiredPos", ["_minVehGap", 12], ["_buildingGap", 10]];
        private _hit = [_desiredPos, 250, _convoyVehiclesSpawned, -1, [], _endPos, _minVehGap, 8, _buildingGap] call FADE_findOpforGroundVehicleRoadSpawn;
        if (_hit isEqualTo []) exitWith { [] };
        _hit select 0
    };
    private _spawnConvoyVehicle = {
        params ["_vClass", "_spawnPos"];
        if (_spawnPos isEqualTo [] || { count _spawnPos < 2 }) exitWith { [objNull, grpNull, grpNull] };
        if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };
        private _roadHit = [_spawnPos, 250, _convoyVehiclesSpawned, -1, [], _endPos] call FADE_findOpforGroundVehicleRoadSpawn;
        if (_roadHit isEqualTo []) exitWith { [objNull, grpNull, grpNull] };
        _roadHit params ["_spawnPos", "_spawnDir"];
        private _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
        if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
        _veh setPosATL _spawnPos;
        _veh setDir _spawnDir;
        _veh setVectorUp surfaceNormal _spawnPos;
        // Small forward nudge helps newly spawned convoy vehicles break static friction/get unstuck.
        private _nudge = 2;
        _veh setVelocity [ (sin _spawnDir) * _nudge, (cos _spawnDir) * _nudge, 0 ];
        private _vehGrp = createGroup _sideEnemy;
        private _cargoGrp = grpNull;
        if (count _enemyUnitsConv > 0) then {
            private _driver = _vehGrp createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
            if (!isNull _driver) then {
                _driver moveInDriver _veh;
                _vehGrp selectLeader _driver;
            };
            if (_veh emptyPositions "gunner" > 0) then {
                private _g = _vehGrp createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _g) then { _g moveInGunner _veh };
            };
            if (_veh emptyPositions "commander" > 0) then {
                private _c = _vehGrp createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _c) then { _c moveInCommander _veh };
            };
        };
        private _cargoSeats = (_veh emptyPositions "cargo") max 0;
        if (_cargoSeats > 0 && { count _enemyUnitsConv > 0 }) then {
            _cargoGrp = createGroup _sideEnemy;
            for "_c" from 0 to (_cargoSeats - 1) do {
                private _u = _cargoGrp createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _u) then { _u moveInCargo _veh };
            };
        };
        [_veh, _enemyUnitsConv] call FADE_ensureEnemyVehicleGunner;
        _veh engineOn true;
        [_veh, _vehGrp, _cargoGrp]
    };

    // Spawn lead vehicle first, then stagger followers to reduce spawn-gridlock.
    if (count _vehicleClasses > 0) then {
        private _leadSpawn = [_startPos, 14, 12] call _findConvoySafeSpawn;
        if !( _leadSpawn isEqualTo [] ) then {
        private _leadResult = [(_vehicleClasses select 0), _leadSpawn] call _spawnConvoyVehicle;
        private _leadVeh = _leadResult select 0;
        _leadGrp = _leadResult select 1;
        if (!isNull _leadVeh && { !isNull _leadGrp }) then {
            _convoyVehiclesSpawned pushBack _leadVeh;
            _convoyVehicleGroups pushBack _leadGrp;
            private _cg = _leadResult select 2;
            if (!isNull _cg) then { _cargoGroups pushBack _cg };
            _convoySpawnEntries pushBack [_leadVeh, (_vehicleClasses select 0), _leadSpawn, false, _cg, _leadGrp];
            // Lead group drives the route; followers chain via FOLLOW waypoints after all spawns.
            _leadGrp setFormation "COLUMN";
            _leadGrp setBehaviour "SAFE";
            _leadGrp setSpeedMode "NORMAL";
            _convoyWp = [_leadGrp, _routeWaypoints] call _applyConvoyLeadRoute;
        };

        for "_v" from 1 to (count _vehicleClasses - 1) do {
            sleep 10;
            private _vClass = _vehicleClasses select _v;
            private _anchorVeh = _convoyVehiclesSpawned param [(count _convoyVehiclesSpawned) - 1, objNull];
            private _anchorPos = if (!isNull _anchorVeh) then { getPosATL _anchorVeh } else { _startPos };
            private _desired = [
                (_anchorPos select 0) - (sin _dir) * 10,
                (_anchorPos select 1) - (cos _dir) * 10,
                0
            ];
            private _safeBehind = [_desired, 12, 10] call _findConvoySafeSpawn;
            if (_safeBehind isEqualTo []) then { continue };
            private _res = [_vClass, _safeBehind] call _spawnConvoyVehicle;
            private _veh = _res select 0;
            private _vehGrp = _res select 1;
            if (!isNull _veh && { !isNull _vehGrp }) then {
                _convoyVehiclesSpawned pushBack _veh;
                _convoyVehicleGroups pushBack _vehGrp;
                private _cg2 = _res select 2;
                if (!isNull _cg2) then { _cargoGroups pushBack _cg2 };
                _convoySpawnEntries pushBack [_veh, _vClass, _safeBehind, false, _cg2, _vehGrp];
            };
        };
        };
    };
    // One-time recovery: respawn exploded or non-moving convoy vehicles once.
    sleep 8;
    for "_i" from 0 to (count _convoySpawnEntries - 1) do {
        private _entry = _convoySpawnEntries select _i;
        _entry params ["_veh", "_vClass", "_spawnPos", "_retried", "_cargoGrp", "_vehGrp"];
        private _needsRespawn = isNull _veh || { !alive _veh } || { !canMove _veh } || { speed _veh < 1 };
        if (_needsRespawn && { !_retried }) then {
            if (!isNull _cargoGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _cargoGrp;
                deleteGroup _cargoGrp;
                _cargoGroups = _cargoGroups - [_cargoGrp];
            };
            if (!isNull _vehGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _vehGrp;
                deleteGroup _vehGrp;
                _convoyVehicleGroups = _convoyVehicleGroups - [_vehGrp];
            };
            if (!isNull _veh) then { deleteVehicle _veh };
            private _retryPos = [_spawnPos, 12, 10] call _findConvoySafeSpawn;
            private _retryRes = [_vClass, _retryPos] call _spawnConvoyVehicle;
            private _retryVeh = _retryRes select 0;
            private _retryGrp = _retryRes select 1;
            private _retryCargo = _retryRes select 2;
            if (!isNull _retryCargo) then { _cargoGroups pushBack _retryCargo };
            if (!isNull _retryGrp) then { _convoyVehicleGroups pushBack _retryGrp };
            if (!isNull _retryVeh) then {
                _entry = [_retryVeh, _vClass, _retryPos, true, _retryCargo, _retryGrp];
                _convoySpawnEntries set [_i, _entry];
            };
        };
    };
    _convoyVehiclesSpawned = (_convoySpawnEntries apply { _x select 0 }) select { !isNull _x && { alive _x } };
    _convoyVehicleGroups = (_convoySpawnEntries apply { _x select 5 }) select { !isNull _x };
    // Chain followers to the vehicle ahead (one crew group per vehicle — avoids subordinate drivers stuck idle).
    for "_i" from 1 to (count _convoySpawnEntries - 1) do {
        (_convoySpawnEntries select _i) params ["_veh", "", "", "", "", "_vehGrp"];
        private _prevVeh = (_convoySpawnEntries select (_i - 1)) select 0;
        if (!isNull _veh && { !isNull _prevVeh } && { !isNull _vehGrp }) then {
            [_vehGrp, _prevVeh] call _setupConvoyFollow;
            _veh setConvoySeparation 20;
        };
    };
    // Cleanup: delete any convoy infantry that failed to board (prevents stragglers at spawn).
    {
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
        } forEach units _x;
    } forEach _convoyVehicleGroups;
    {
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
        } forEach units _x;
    } forEach _cargoGroups;
    { [_x] call FAC_applyEnemyScenarioToGroup } forEach _convoyVehicleGroups;
    { [_x] call FAC_applyEnemyScenarioToGroup } forEach _cargoGroups;
    if (count _convoyVehiclesSpawned == 0) exitWith {
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _convoyVehicleGroups;
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGroups;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn convoy vehicles.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Lead MOVE wp (refreshed after recovery / follow chain so respawned lead still drives).
    _leadGrp = (_convoySpawnEntries param [0, []]) param [5, grpNull];
    if (isNull _leadGrp) then { _leadGrp = _convoyVehicleGroups param [0, grpNull] };
    if (!isNull _leadGrp) then {
        _convoyWp = [_leadGrp, _routeWaypoints] call _applyConvoyLeadRoute;
    };
    if (!isNull _leadGrp) then {
        _leadGrp setVariable ["FADE_convoyTaskId", _taskId, true];
        _leadGrp setVariable ["FADE_convoyVehiclesList", _convoyVehiclesSpawned, true];
        _leadGrp setVariable ["FADE_convoyCargoGroups", _cargoGroups, true];
        _leadGrp setVariable ["FADE_convoyVehicleGroups", _convoyVehicleGroups, true];
    };
    {
        if (!isNull _x) then { _x setConvoySeparation 20 };
    } forEach _convoyVehiclesSpawned;
    if (!isNull _convoyWp) then {
        _convoyWp setWaypointStatements ["true", "
        private _g = group this;
        private _task = _g getVariable ['FADE_convoyTaskId', ''];
        if (_task != '' && { (_task call BIS_fnc_taskState) != 'SUCCEEDED' }) then { [_task, 'FAILED'] call BIS_fnc_taskSetState };
        private _vList = _g getVariable ['FADE_convoyVehiclesList', []];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _vList;
        private _cargoGrps = _g getVariable ['FADE_convoyCargoGroups', []];
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGrps;
        private _vehGrps = _g getVariable ['FADE_convoyVehicleGroups', []];
        {
            if (!isNull _x && { _x != _g }) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
                deleteGroup _x;
            };
        } forEach _vehGrps;
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
        deleteGroup _g;
    "];
    };
    [_convoyVehicleGroups + _cargoGroups, _basePos] call FADE_registerEnemyRetreat;
    { [_taskId, _x] call FADE_missionEnt_registerGroup } forEach _convoyVehicleGroups;
    { [_taskId, _x] call FADE_missionEnt_registerGroup } forEach _cargoGroups;
    { [_taskId, _x] call FADE_missionEnt_registerVehicle } forEach _convoyVehiclesSpawned;
    private _markerNameStart = "FADE_convoy_start_" + _taskId;
    private _markerNameEnd = "FADE_convoy_end_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerNameStart, true];
    _player setVariable ["FADE_myMissionMarkerEnd", _markerNameEnd, true];
    private _markerStart = createMarker [_markerNameStart, [_startPos, 100] call _mkrJitter];
    [_taskId, _markerNameStart] call FADE_missionEnt_registerMarker;
    _markerStart setMarkerType "mil_arrow";
    _markerStart setMarkerColor _markerEnemy;
    _markerStart setMarkerText _operationName;
    private _markerEnd = createMarker [_markerNameEnd, [_endPos, 100] call _mkrJitter];
    [_taskId, _markerNameEnd] call FADE_missionEnt_registerMarker;
    _markerEnd setMarkerType "mil_end";
    _markerEnd setMarkerColor _markerEnemy;
    _markerEnd setMarkerText _operationName;
    for "_ri" from 1 to ((count _routeWaypoints) - 2) do {
        private _routePos = _routeWaypoints select _ri;
        private _routeMarkerName = format ["FADE_convoy_route_%1_%2", _taskId, _ri];
        private _routeMarker = createMarker [_routeMarkerName, _routePos];
        [_taskId, _routeMarkerName] call FADE_missionEnt_registerMarker;
        _routeMarker setMarkerType "mil_dot";
        _routeMarker setMarkerColor _markerEnemy;
        _routeMarker setMarkerAlpha 0.85;
    };
    if (count _routeWaypoints >= 2) then {
        private _polylinePath = [];
        {
            _polylinePath append [(_x select 0), (_x select 1)];
        } forEach _routeWaypoints;
        if (count _polylinePath >= 4) then {
            private _routeLineName = format ["FADE_convoy_route_line_%1", _taskId];
            private _routeLine = createMarker [_routeLineName, _startPos];
            [_taskId, _routeLineName] call FADE_missionEnt_registerMarker;
            _routeLine setMarkerShape "POLYLINE";
            _routeLine setMarkerColor _markerEnemy;
            _routeLine setMarkerAlpha 0.55;
            _routeLine setMarkerPolyline _polylinePath;
        };
    };
    [_player, _taskId, "Stop the convoy: destroy or immobilise at least 60% of vehicles before they reach the end zone.", "Intercept Convoy", _endPos, "destroy"] call _fnc_createMissionTask;
    private _gridStart = mapGridPosition _startPos;
    private _gridEnd = mapGridPosition _endPos;
    private _brief = format ["INTERCEPT CONVOY%1%1Corridor (approx.): Grid %2 to Grid %3. Enemy dots and route line mark the expected convoy path.%1%1Ambush or stop the convoy before it reaches the end grid. Disable or destroy the majority of vehicles as defined on the task to complete.", toString [10], _gridStart, _gridEnd] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Start: %1 -> End: %2</t><br/><br/><t color='#FFFFFF'>Route markers show the expected convoy path. Stop at least 60%% of vehicles destroyed or immobilised.</t>", _gridStart, _gridEnd]] call _showAssignedHint;
    if (!isNull _player) then {
        [format ["INTERCEPT CONVOY: Mission ready — route %1 to %2. Check Tasks for orders.", _gridStart, _gridEnd]] remoteExec ["systemChat", _player];
    };
    [_player, "Intercept Convoy"] call FADE_notifyOthersMissionStarted;
    private _friendlyObserverClass = _friendlyUnits select 0;
    [_taskId, _convoyVehiclesSpawned, _leadGrp, _cargoGroups, _markerNameStart, _markerNameEnd, _player, _endPos, _startPos, _friendlyObserverClass, _sideFriendly] spawn {
        params ["_taskId", "_convoyVehiclesSpawned", "_leadGrp", "_cargoGroups", "_markerNameStart", "_markerNameEnd", "_player", "_endPos", "_startPos", "_friendlyObserverClass", "_sideFriendly"];
        private _warningSent = false;
        private _routeDist = (_startPos distance _endPos) max 1;
        private _warningDist = (_routeDist * 0.35) max 400;
        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
            // RATEL observer warning when convoy nears objective
            if (!_warningSent) then {
                private _leadVeh = (_convoyVehiclesSpawned select { (!isNull _x) && { alive _x } }) param [0, objNull];
                if (!isNull _leadVeh && { (_leadVeh distance _endPos) <= _warningDist }) then {
                    _warningSent = true;
                    private _observerGrp = createGroup _sideFriendly;
                    private _observer = _observerGrp createUnit [_friendlyObserverClass, [0, 0, 0], [], 0, "NONE"];
                    _observer setIdentity "FADE_ratel_eagleeye";
                    private _dist = round (_leadVeh distance _endPos);
                    private _msgs = [
                        format ["All callsigns, this is Eagle Eye. Convoy is tracking, %1 metres from end zone. Expedite intercept. Out.", _dist],
                        "All callsigns, this is Eagle Eye. Visual on convoy. Multiple vehicles, closing on objective. Intercept immediately. Out.",
                        "All callsigns, this is Eagle Eye. Be advised - the convoy is nearing the edge of the AO. Over.",
                        "All callsigns, this is Eagle Eye. Hostile convoy will be leaving the AO shortly. All assets, engage now. Out."
                    ];
                    [_observer, selectRandom _msgs] call FADE_aiSideChat;
                    [_observer, _observerGrp] spawn {
                        params ["_o", "_g"];
                        sleep 4;
                        if (!isNull _o) then { deleteVehicle _o };
                        if (!isNull _g) then { deleteGroup _g };
                    };
                };
            };
            // Success when 60%+ of convoy vehicles are inoperable (destroyed or immobile)
            private _total = count _convoyVehiclesSpawned;
            private _inoperable = 0;
            {
                if (isNull _x || { !alive _x } || { !canMove _x }) then { _inoperable = _inoperable + 1 };
            } forEach _convoyVehiclesSpawned;
            if (_total > 0 && { _inoperable >= (ceil (_total * 0.6)) }) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            } else { false };
        };
        [_markerNameStart] call FADE_deleteMarkerSafe;
        [_markerNameEnd] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
    };
};

