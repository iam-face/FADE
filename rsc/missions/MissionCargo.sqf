// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_Cargo = {
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
    if (isNil "FADE_cargoClasses" || { count FADE_cargoClasses == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No cargo classes configured."] call FADE_missionErrorHint;
    };
    private _cargoClass = selectRandom FADE_cargoClasses;
    if (isNil "_cargoClass" || { _cargoClass == "" }) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "Invalid cargo class."] call FADE_missionErrorHint;
    };
    // Spawn cargo at CargoPoint_1 marker; findSafePos avoids clipping with vehicles
    private _cargoCenter = getMarkerPos "CargoPoint_1";
    if (_cargoCenter isEqualTo [0,0,0]) then { _cargoCenter = _basePos };
    if (count _cargoCenter < 3) then { _cargoCenter = [(_cargoCenter select 0), (_cargoCenter select 1), 0] };
    private _cargoPos = [[_cargoCenter, 0, 8, 4, 1, 0.3, 0, [], _cargoCenter], _cargoCenter] call FADE_findSafePosArray;
    _cargoPos = [(_cargoPos select 0), (_cargoPos select 1), (_cargoPos param [2, 0])];
    private _cargo = createVehicle [_cargoClass, _cargoPos, [], 0, "NONE"];
    _cargo setPosATL _cargoPos;
    _cargo enableRopeAttach true;

    // Small camp composition at destination (BIS-style: createVehicle at relative positions)
    private _campObjects = [];
    // [classname, distance from center, angle, object rotation offset]
    private _campComposition = [
        ["Land_TentA_F", 8, 0, 0],
        ["Land_TentDome_F", 10, 180, 0],
        ["Land_CampingTable_F", 5, 90, 0],
        ["Land_CampingChair_V2_F", 6, 120, 0],
        ["Land_CampingChair_V2_F", 6, 60, 0],
        ["Campfire_burning_F", 4, 270, 0],
        ["Box_NATO_Ammo_F", 12, 45, 0],
        ["Box_NATO_Support_F", 12, 315, 0]
    ];
    {
        _x params ["_class", "_dist", "_angle", "_dirObj"];
        private _pos = [(_destPos select 0) + _dist * (cos _angle), (_destPos select 1) + _dist * (sin _angle), (_destPos param [2, 0])];
        _pos = [[_pos, 0, 2, 0, 1, 0.3, 0, [], _pos], _pos] call FADE_findSafePosArray;
        if (_pos isEqualType [] && { count _pos >= 2 }) then {
            _pos = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            private _obj = createVehicle [_class, _pos, [], 0, "NONE"];
            _obj setDir (_angle + _dirObj);
            _obj setPosATL _pos;
            if (surfaceIsWater _pos) then { _obj setPosATL [_pos select 0, _pos select 1, 0] } else { _obj setVectorUp surfaceNormal _pos };
            _campObjects pushBack _obj;
            [_taskId, _obj] call FADE_missionEnt_registerObject;
        };
    } forEach _campComposition;

    // Single receiving unit (the one who walks to the helicopter and confirms unload)
    private _receiverClass = _friendlyUnits select 0;
    private _garrisonPos = [[_destPos, 0, 8, 2, 1, 0.3, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
    if (count _garrisonPos < 2) then { _garrisonPos = _destPos };
    private _garrisonGroup = [_garrisonPos, _sideFriendly, [_receiverClass]] call BIS_fnc_spawnGroup;
    [_taskId, _garrisonGroup] call FADE_missionEnt_registerGroup;
    [_garrisonGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    _garrisonGroup setBehaviour "SAFE";
    _garrisonGroup setCombatMode "GREEN";
    {
        private _p = [[_garrisonPos, 0, 3, 0, 1, 0.2, 0, [], _garrisonPos], _garrisonPos] call FADE_findSafePosArray;
        if (_p isEqualType [] && { count _p >= 2 }) then { _x setPos [(_p select 0), (_p select 1), (_p param [2, 0])] };
        doStop _x;
    } forEach (units _garrisonGroup);

    // Two patrol groups (2-4 units each) patrolling 200m radius of camp
    private _cargoPatrolGroups = [];
    for "_pg" from 0 to 1 do {
        private _patrolSize = 2 + floor random 3;
        private _patrolClasses = (_friendlyUnits select [0, _patrolSize min count _friendlyUnits]);
        for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_friendlyUnits select 0) };
        private _patrolAngle = _pg * 180 + (random 60);
        private _patrolDist = 30 + random 80;
        private _psp = [(_destPos select 0) + _patrolDist * (cos _patrolAngle), (_destPos select 1) + _patrolDist * (sin _patrolAngle), 0];
        _psp = [[_psp, 0, 15, 3, 1, 0.3, 0, [], _psp], _psp] call FADE_findSafePosArray;
        if (count _psp < 2) then { _psp = _destPos };
        private _pg_grp = [_psp, _sideFriendly, _patrolClasses] call BIS_fnc_spawnGroup;
        [_pg_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
        _pg_grp setBehaviour "SAFE";
        _pg_grp setCombatMode "GREEN";
        for "_w" from 0 to 3 do {
            private _wa = _w * 90 + (random 30);
            private _wd = 80 + random 120;
            private _wpPos = [(_destPos select 0) + _wd * (cos _wa), (_destPos select 1) + _wd * (sin _wa), 0];
            _wpPos = [[_wpPos, 0, 10, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                private _wp = _pg_grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                if (_w == 3) then { _wp setWaypointType "CYCLE" };
            };
        };
        _cargoPatrolGroups pushBack _pg_grp;
        [_taskId, _pg_grp] call FADE_missionEnt_registerGroup;
    };

    [_player, _taskId, "Deliver cargo to the camp. Land at the camp for the receiving party to unload.", "Cargo / Resupply", _destPos, "box"] call _fnc_createMissionTask;

    private _markerName = "FADE_cargo_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _campLandingRadius = 50;
    [_taskId, _markerName + "_zone", _destPos, _campLandingRadius, "ColorOrange"] call FADE_mission_createRadiusMarker;
    private _marker = [_markerName, [_destPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
    _marker setMarkerType "loc_bunker";
    _marker setMarkerColor "ColorOrange";
    _marker setMarkerText _operationName;

    // Cargo box pickup marker - only visible while this mission is active
    private _cargoPickupMarkerName = "FADE_cargoPickup_" + _taskId;
    private _cargoPickupMarker = [_cargoPickupMarkerName, [_cargoPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
    _cargoPickupMarker setMarkerType "mil_box";
    _cargoPickupMarker setMarkerColor "ColorWEST";
    _cargoPickupMarker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _cargoGrid = mapGridPosition _cargoPos;
    private _brief = format ["CARGO / RESUPPLY%1%1Camp (approx.): Grid %2%1Optional sling box (approx.): Grid %3%1%1Deliver supplies to the camp. Land to unload or use sling operations as directed. Completion is confirmed by handover or mission rules.", toString [10], _grid, _cargoGrid] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#FFFFFF'>Camp Grid: %1</t><br/><t color='#FFFFFF'>Cargo Box: Grid %2 (optional sling load)</t><br/><br/><t color='#FFFFFF'>Fly to camp and land to complete. Delivering the box is optional.</t>", _grid, _cargoGrid]] call _showAssignedHint;
    [_player, "Cargo / Resupply"] call FADE_notifyOthersMissionStarted;

    [_taskId, _cargo, _destPos, _markerName, 900, _player, _campObjects, _garrisonGroup, _cargoPatrolGroups, _cargoPickupMarkerName] spawn {
        params ["_taskId", "_cargo", "_destPos", "_markerName", "_timeout", "_player", "_campObjects", "_garrisonGroup", "_cargoPatrolGroups", "_cargoPickupMarkerName"];
        private _start = time;
        private _unloadStarted = false;
        private _unloadStartTime = 0;
        private _contactMsgSent = false;
        private _receivingUnit = objNull;
        private _callsign = if (!isNull _garrisonGroup) then { _garrisonGroup getVariable ["FADE_callsign", "Alpha 1-1"] } else { "Alpha 1-1" };
        if (!isNull _garrisonGroup && { count units _garrisonGroup > 0 }) then { _receivingUnit = leader _garrisonGroup };

        private _waitDone = false;
        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _waitDone = true };

            if (!_waitDone && { time - _start > _timeout }) then { _waitDone = true };

            if (!_waitDone && !_unloadStarted && !isNull _player && { alive _player }) then {
                private _veh = vehicle _player;
                private _refPos = if (_veh == _player) then { _player } else { _veh };
                private _nearCamp = _refPos distance _destPos < 50;
                if (_nearCamp && !_contactMsgSent && !isNull _receivingUnit && { alive _receivingUnit }) then {
                    [_receivingUnit, format ["This is %1. We have you in sight. Land when ready. Over.", _callsign]] call FADE_aiSideChat;
                    _contactMsgSent = true;
                };
                private _isHeli = _veh isKindOf "Helicopter" && _veh != _player;
                private _landedHeli = _isHeli && { (isTouchingGround _veh) || ((getPosATL _veh select 2) < 2.5 && speed _veh < 6) };
                private _onFootAtCamp = _veh == _player && { _player distance _destPos < 45 };
                if ((_landedHeli || _onFootAtCamp) && _nearCamp && !isNull _receivingUnit && { alive _receivingUnit }) then {
                    _unloadStarted = true;
                    _unloadStartTime = time;
                    private _targetVeh = if (_veh == _player) then { objNull } else { _veh };
                    if (!isNull _targetVeh) then {
                        [_receivingUnit, format ["This is %1. Moving to receive. Over.", _callsign]] call FADE_aiSideChat;
                        private _approachPos = _targetVeh getPos [8, getDir _targetVeh];
                        _approachPos = [[_approachPos, 0, 2, 0, 1, 0.3, 0, [], _approachPos], _approachPos] call FADE_findSafePosArray;
                        if (_approachPos isEqualType [] && { count _approachPos >= 2 }) then {
                            _approachPos = [(_approachPos select 0), (_approachPos select 1), (_approachPos param [2, 0])];
                            _receivingUnit doMove _approachPos;
                        } else {
                            _receivingUnit doMove (getPos _targetVeh);
                        };
                    } else {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_taskId, _markerName, _player, 60, [_markerName + "_zone", _cargoPickupMarkerName]] call FADE_mission_completeCleanup;
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups, 60] call FADE_cargo_cleanupSiteDeferred;
                        _waitDone = true;
                    };
                };
            };

            if (!_waitDone && _unloadStarted && !isNull _receivingUnit && { alive _receivingUnit }) then {
                private _veh = vehicle _player;
                if (_veh == _player) then { _veh = objNull };
                if (!isNull _veh && { _receivingUnit distance _veh < 10 }) then {
                    doStop _receivingUnit;
                    _receivingUnit switchMove "AinvPknlMstpSnonWnonDnon_medic0";
                    [_receivingUnit, format ["This is %1. Receiving. Offloading cargo, give me a few seconds. Out.", _callsign]] call FADE_aiSideChat;
                    sleep 5;
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    [_taskId, _markerName, _player, 60, [_markerName + "_zone", _cargoPickupMarkerName]] call FADE_mission_completeCleanup;
                    [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups, 60] call FADE_cargo_cleanupSiteDeferred;
                    _waitDone = true;
                } else {
                    if (time - _unloadStartTime > 25) then {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_taskId, _markerName, _player, 60, [_markerName + "_zone", _cargoPickupMarkerName]] call FADE_mission_completeCleanup;
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups, 60] call FADE_cargo_cleanupSiteDeferred;
                        _waitDone = true;
                    };
                };
            };

            _waitDone
        };

        if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_taskId, _markerName, _player, 60, [_markerName + "_zone", _cargoPickupMarkerName]] call FADE_mission_completeCleanup;
        if ((_taskId call BIS_fnc_taskState) != "SUCCEEDED") then {
            [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups, 60] call FADE_cargo_cleanupSiteDeferred;
        };
    };
};

