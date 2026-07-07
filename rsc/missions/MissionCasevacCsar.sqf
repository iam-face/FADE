// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_CASEVAC = {
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
    private _maxPax = _unitCount max 2;
    private _pickupCount = ((2 + floor random 9) min _maxPax) max 2;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wreckData = [_destPos, _taskId] call FADE_mission_spawnCasualtyHeliWreck;
    _wreckData params ["_wreck", "_airClass", "_crashPos", "_usedLiveHeli"];
    private _survPos = [_crashPos getPos [10, random 360], 10, 8] call FADE_mission_findPickupSpawnPos;
    if (count _survPos < 2) then { _survPos = +_crashPos };

    private _groupData = [_destPos, _sideFriendly, _pickupClasses, _survPos] call FADE_mission_spawnFriendlyPickupGroup;
    _groupData params ["_group", "_wpPos"];

    [_group] call FADE_mission_casevacCasualtyPrep;

    private _enemyGroups = [
        _destPos, _basePos, _enemyUnits, _sideEnemy, _taskId, _scaleOpforCount
    ] call FADE_mission_spawnFieldContactEnemies;
    [_group, count _enemyGroups > 0] call FADE_mission_applyPickupGroupPosture;

    [_player, _taskId, "CASEVAC: extract casualties and return to base.", "CASEVAC", _destPos, "move", "", format [
        "<t align='left' color='#C0C0C0'>1. Fly to the pickup marker and land.<br/>2. Load all wounded  -  they may need to be carried or assisted aboard.<br/>3. RTB and land at base to complete the mission.</t>"
    ]] call _fnc_createMissionTask;

    private _markerName = "FADE_casevac_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _casevacPickupRadius = 200;
    [_taskId, _markerName + "_zone", _destPos, _casevacPickupRadius, _markerFriendly] call FADE_mission_createRadiusMarker;
    private _marker = [_markerName, [_destPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
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
    private _pickupClasses = [_friendlyUnits select 0];
    private _wreckData = [_destPos, _taskId] call FADE_mission_spawnCasualtyHeliWreck;
    _wreckData params ["_wreck", "_csarAircraftClass", "_wpPos", "_usedFactionHeli"];

    private _survPos = +_wpPos;
    if (!isNull _wreck) then {
        _survPos = [_wreck getPos [10, random 360], 10, 8] call FADE_mission_findPickupSpawnPos;
        if (count _survPos < 2) then { _survPos = getPosATL _wreck };
    };
    private _groupData = [_destPos, _sideFriendly, _pickupClasses, _survPos] call FADE_mission_spawnFriendlyPickupGroup;
    _groupData params ["_group", "_survPos"];
    { _x allowDamage false } forEach units _group;
    private _crashCenter = if (!isNull _wreck) then { getPosATL _wreck } else { +_wpPos };
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
        _kiaPos = [_kiaPos] call FADE_mission_groundAtlPos;
        private _kiaGroup = createGroup [_sideFriendly, true];
        private _kiaUnit = _kiaGroup createUnit [_kiaClass, _kiaPos, [], 0, "NONE"];
        _kiaUnit setPosATL _kiaPos;
        _kiaUnit setDir (random 360);
        _kiaUnit setDamage 1;
        _kiaUnit disableAI "ALL";
        _csarBodies pushBack _kiaUnit;
    };
    missionNamespace setVariable ["FADE_csarBodies_" + _taskId, _csarBodies];

    [_group] call FADE_mission_csarPilotWoundPrep;

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
            _grp setSpeedMode "FULL";
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
            _wpCrash setWaypointSpeed "FULL";
            _wpCrash setWaypointBehaviour "SAFE";
            _wpCrash setWaypointCombatMode "GREEN";
            _wpCrash setWaypointFormation "LINE";
            _wpCrash setWaypointCompletionRadius 35;
            private _wpTown = _grp addWaypoint [_townWpPos, 0];
            _wpTown setWaypointType "MOVE";
            _wpTown setWaypointSpeed "FULL";
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
    private _csarPickupRadius = 200;
    [_taskId, _markerName + "_zone", _destPos, _csarPickupRadius, _markerFriendly] call FADE_mission_createRadiusMarker;
    private _marker = [_markerName, [_destPos] call FADE_normPos3, _taskId] call FADE_createRegisteredMarker;
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
            private _sfPlayers = ([] call FADE_getAlivePlayers) select { side group _x == _sf };
            private _minD = 1e10;
            {
                private _d = _x distance _ldr;
                if (_d < _minD) then { _minD = _d };
            } forEach _sfPlayers;
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
                            private _veh = vehicle _x;
                            if (_veh != _x && { alive _veh } && { canMove _veh }) then {
                                private _dVeh = _survivor distance _veh;
                                if (_dVeh < _nearestDist) then {
                                    _nearestVeh = _veh;
                                    _nearestDist = _dVeh;
                                };
                            };
                        } forEach _sfPlayers;

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

