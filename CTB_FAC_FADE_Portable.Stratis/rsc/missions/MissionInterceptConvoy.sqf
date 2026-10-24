// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_InterceptConvoy = {
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
    private _efConv = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _convoyVehicles = [_efConv] call FADE_getEnemyVehiclesForFaction;
    if (_convoyVehicles isEqualTo []) then {
        _convoyVehicles = +(missionNamespace getVariable ["FADE_enemyVehicles", []]);
    };
    private _enemyUnitsConv = +_enemyUnits;
    _enemyUnitsConv = [_enemyUnitsConv] call (missionNamespace getVariable ["FADE_filterUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsConv == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No enemy units configured for convoy crew."] call FADE_missionErrorHint;
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
        [_player, "MISSION ERROR", "Enemy faction has no land vehicles. Choose a faction with cars/trucks or light armour."] call FADE_missionErrorHint;
    };
    if (isNil "FADE_interceptConvoyRoadRoute" || { isNil "FADE_interceptConvoyRouteWaypoints" }) exitWith {
        [_player, "MISSION ERROR", "Convoy route helper not loaded."] call FADE_missionErrorHint;
    };
    private _clickRoute = ([_mapPickRawAnchor] call FADE_fnc_isValidMapClickPos) && { [_convoyEndRaw] call FADE_fnc_isValidMapClickPos };
    private _route = if (_clickRoute) then {
        [_basePos, -1, _mapPickRawAnchor, -1, _convoyEndRaw] call FADE_interceptConvoyRoadRoute
    } else {
        if ([_mapAnchor] call FADE_fnc_isValidMapClickPos) then {
            [_basePos, -1, _mapAnchor, -1] call FADE_interceptConvoyRoadRoute
        } else {
            [_basePos] call FADE_interceptConvoyRoadRoute
        };
    };
    if (!(_route isEqualType []) || { count _route < 2 }) exitWith {
        [_player] call FADE_clearActiveMission;
        private _needM = if (!isNil "FADE_convoyEffectiveMinM") then {
            [_clickRoute] call FADE_convoyEffectiveMinM
        } else {
            missionNamespace getVariable ["FADE_convoyRouteFloorM", 1200]
        };
        private _msg = if (_clickRoute) then {
            format ["Could not build a convoy route from those clicks. Each point needs a road within 500 m. Keep the points at least %1 m apart, and away from base.", round _needM]
        } else {
            format ["Could not find a convoy route on roads at least %1 m apart. Try again.", round _needM]
        };
        [_player, "MISSION ERROR", _msg] call FADE_missionErrorHint;
    };
    private _startPos = _route select 0;
    private _endPos = _route select ((count _route) - 1);
    if (count _startPos < 3) then { _startPos = [(_startPos select 0), (_startPos select 1), 0] };
    if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };

    private _pointAlong = {
        params ["_pts", "_dist"];
        private _out = _pts select 0;
        private _remain = _dist;
        private _a = [];
        private _b = [];
        private _seg = 0;
        private _t = 0;
        private _pi = 0;
        if (_dist <= 0 || { count _pts < 2 }) exitWith { _out };
        _out = _pts select ((count _pts) - 1);
        for "_pi" from 0 to ((count _pts) - 2) do {
            if (_remain >= 0) then {
                _a = _pts select _pi;
                _b = _pts select (_pi + 1);
                _seg = _a distance2D _b;
                if (_remain <= _seg) then {
                    _t = if (_seg <= 0.1) then { 0 } else { _remain / _seg };
                    _out = [
                        (_a select 0) + (((_b select 0) - (_a select 0)) * _t),
                        (_a select 1) + (((_b select 1) - (_a select 1)) * _t),
                        0
                    ];
                    _remain = -1;
                } else {
                    _remain = _remain - _seg;
                };
            };
        };
        _out
    };
    private _pathLen = 0;
    private _segI = 0;
    for "_segI" from 0 to ((count _route) - 2) do {
        _pathLen = _pathLen + ((_route select _segI) distance2D (_route select (_segI + 1)));
    };
    private _routeWaypoints = [];
    private _sampleD = 0;
    while { _sampleD < _pathLen } do {
        _routeWaypoints pushBack ([_route, _sampleD] call _pointAlong);
        _sampleD = _sampleD + 200;
    };
    _routeWaypoints pushBack _endPos;
    if ((count _routeWaypoints) >= 2 && { ((_routeWaypoints select ((count _routeWaypoints) - 2)) distance2D _endPos) < 15 }) then {
        _routeWaypoints deleteAt ((count _routeWaypoints) - 2);
    };

    private _applyConvoyLeadRoute = {
        params ["_grp", "_wps"];
        if (isNull _grp || { _wps isEqualTo [] } || { count _wps < 2 }) exitWith { objNull };
        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
        _grp setFormation "COLUMN";
        _grp setBehaviour "SAFE";
        _grp setSpeedMode "NORMAL";
        private _lastWp = objNull;
        private _wi = 0;
        private _wpPos = [];
        private _wp = objNull;
        for "_wi" from 1 to ((count _wps) - 1) do {
            _wpPos = _wps select _wi;
            _wp = _grp addWaypoint [_wpPos, 20];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "NORMAL";
            _lastWp = _wp;
        };
        _lastWp
    };
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

    private _convoySize = [3 + floor random 4, 2] call _scaleOpforCount;
    private _numArmored = (([floor random 3, 0] call _scaleOpforCount) min 2) min _convoySize;
    private _vehicleClasses = [];
    private _v = 0;
    for "_v" from 0 to (_convoySize - 1) do {
        if (_v < _numArmored && { count _armored > 0 }) then {
            _vehicleClasses pushBack (selectRandom _armored);
        } else {
            if (count _soft > 0) then { _vehicleClasses pushBack (selectRandom _soft) } else { _vehicleClasses pushBack (selectRandom _armored) };
        };
    };

    private _convoyVehicleGroups = [];
    private _convoyVehiclesSpawned = [];
    private _cargoGroups = [];
    private _leadGrp = grpNull;
    private _nVeh = count _vehicleClasses;
    private _gap = 28;
    if (_nVeh > 1 && { ((_nVeh - 1) * _gap) > ((_pathLen - 20) max _gap) }) then {
        _gap = ((_pathLen - 20) max 8) / (_nVeh - 1);
    };
    private _spawnPos = [];
    private _ahead = [];
    private _spawnDir = 0;
    private _along = 0;
    private _vClass = "";
    private _spawnRes = [];
    private _veh = objNull;
    private _vehGrp = grpNull;
    private _cargoGrp = grpNull;
    for "_v" from 0 to (_nVeh - 1) do {
        _vClass = _vehicleClasses select _v;
        _along = (_nVeh - 1 - _v) * _gap;
        _spawnPos = [_route, _along] call _pointAlong;
        _ahead = [_route, (_along + 20) min _pathLen] call _pointAlong;
        _spawnDir = if (_spawnPos distance2D _ahead < 1) then {
            [_spawnPos, _endPos] call BIS_fnc_dirTo
        } else {
            [_spawnPos, _ahead] call BIS_fnc_dirTo
        };
        _spawnRes = [
            _vClass, _spawnPos, _spawnDir, _enemyUnitsConv, _sideEnemy,
            ["driver", "gunner", "commander", "cargo"], "random", true, -1, 2, -1, 1
        ] call FADE_spawnCrewedGroundVehicle;
        _veh = _spawnRes select 0;
        _vehGrp = _spawnRes select 1;
        _cargoGrp = _spawnRes select 2;
        if (!isNull _veh && { !isNull _vehGrp }) then {
            _convoyVehiclesSpawned pushBack _veh;
            _convoyVehicleGroups pushBack _vehGrp;
            if (!isNull _cargoGrp) then { _cargoGroups pushBack _cargoGrp };
            if (isNull _leadGrp) then { _leadGrp = _vehGrp };
        };
    };
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
        [_player, "MISSION ERROR", "Could not spawn convoy vehicles."] call FADE_missionErrorHint;
    };
    if (!isNull _leadGrp) then {
        [_leadGrp, _routeWaypoints] call _applyConvoyLeadRoute;
    };
    private _fi = 0;
    for "_fi" from 1 to ((count _convoyVehiclesSpawned) - 1) do {
        _veh = _convoyVehiclesSpawned select _fi;
        _vehGrp = _convoyVehicleGroups select _fi;
        if (!isNull _veh && { !isNull _vehGrp }) then {
            [_vehGrp, _convoyVehiclesSpawned select (_fi - 1)] call _setupConvoyFollow;
            _veh setConvoySeparation 20;
        };
    };
    [_convoyVehicleGroups + _cargoGroups, _basePos] call FADE_registerEnemyRetreat;
    { [_taskId, _x] call FADE_missionEnt_registerGroup } forEach _convoyVehicleGroups;
    { [_taskId, _x] call FADE_missionEnt_registerGroup } forEach _cargoGroups;
    { [_taskId, _x] call FADE_missionEnt_registerVehicle } forEach _convoyVehiclesSpawned;
    private _markerNameStart = "FADE_convoy_start_" + _taskId;
    private _markerNameEnd = "FADE_convoy_end_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerNameStart, true];
    _player setVariable ["FADE_myMissionMarkerEnd", _markerNameEnd, true];
    private _markerStart = [_markerNameStart, [_startPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
    _markerStart setMarkerType "mil_arrow";
    _markerStart setMarkerColor _markerEnemy;
    _markerStart setMarkerText _operationName;
    private _markerEnd = [_markerNameEnd, [_endPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
    _markerEnd setMarkerType "mil_end";
    _markerEnd setMarkerColor _markerEnemy;
    _markerEnd setMarkerText _operationName;
    if (count _routeWaypoints >= 2) then {
        private _polylinePath = [];
        {
            _polylinePath append [(_x select 0), (_x select 1)];
        } forEach _routeWaypoints;
        if (count _polylinePath >= 4) then {
            private _routeLineName = format ["FADE_convoy_route_line_%1", _taskId];
            private _routeLine = [_routeLineName, _startPos, _taskId] call FADE_createRegisteredMarker;
            _routeLine setMarkerShape "POLYLINE";
            _routeLine setMarkerColor _markerEnemy;
            _routeLine setMarkerAlpha 0.55;
            _routeLine setMarkerPolyline _polylinePath;
        };
    };
    [_player, _taskId, "Stop the convoy: destroy or immobilise at least 60% of vehicles before they reach the end zone.", "Intercept Convoy", _endPos, "destroy"] call _fnc_createMissionTask;
    private _gridStart = mapGridPosition _startPos;
    private _gridEnd = mapGridPosition _endPos;
    private _brief = format ["INTERCEPT CONVOY%1Start: grid %2. End: grid %3.%1Follow the route line.%1Destroy or immobilise at least 60%% of the vehicles before they reach the end.", toString [10], _gridStart, _gridEnd] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Start: %1. End: %2.</t><br/><br/><t color='#FFFFFF'>Follow the route line. Destroy or immobilise at least 60%% of the vehicles before the end.</t>", _gridStart, _gridEnd]] call _showAssignedHint;
    if (!isNull _player) then {
        [format ["INTERCEPT CONVOY: Ready - route %1 to %2. Check Tasks for orders.", _gridStart, _gridEnd]] remoteExec ["systemChat", _player];
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
            if (!_warningSent) then {
                private _leadVeh = (_convoyVehiclesSpawned select { (!isNull _x) && { alive _x } }) param [0, objNull];
                if (!isNull _leadVeh && { (_leadVeh distance _endPos) <= _warningDist }) then {
                    _warningSent = true;
                    private _observerGrp = [[[0, 0, 0]], _sideFriendly, [_friendlyObserverClass]] call FADE_spawnInfantryAtPositions;
                    if (!isNull _observerGrp) then {
                    private _observer = leader _observerGrp;
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
            };
            private _total = count _convoyVehiclesSpawned;
            private _inoperable = 0;
            {
                if (isNull _x || { !alive _x } || { !canMove _x }) then { _inoperable = _inoperable + 1 };
            } forEach _convoyVehiclesSpawned;
            if (_total > 0 && { _inoperable >= (ceil (_total * 0.6)) }) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            } else {
                private _columnLead = _convoyVehiclesSpawned param [0, objNull];
                if (!isNull _columnLead && { alive _columnLead } && { canMove _columnLead } && { (_columnLead distance2D _endPos) <= 50 }) then {
                    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                    true
                } else {
                    false
                };
            };
        };
        [_taskId, _markerNameStart, _player, 60, [_markerNameEnd]] call FADE_mission_completeCleanup;
    };
};
