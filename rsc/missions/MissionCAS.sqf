// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_CAS = {
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
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Friendly position first (200-400m from objective center); enemies spawn min 750m from friendlies
    private _friendlyPos = [[_destPos, 200, 400, 5, 1, 0, 0, [], _destPos], _destPos] call FADE_findSafePosArray;
    private _minEnemyDistFromFriendlies = 750;
    private _numGroups = [2 + floor random 3, 1] call _scaleOpforCount;  // 2 to 4 groups
    private _enemyGroups = [];
    private _groupOffset = 30;  // meters between group spawn rings

    for "_g" from 0 to (_numGroups - 1) do {
        private _angle = random 360;
        private _dist = _minEnemyDistFromFriendlies + (_groupOffset * _g) + (random 80);  // 750m+ from friendlies
        private _grpPos = _friendlyPos getPos [_dist, _angle];
        _grpPos = [[_grpPos, 0, 25, 3, 1, 0.4, 0, [], _grpPos], _grpPos] call FADE_findSafePosArray;
        if (count _grpPos < 2) then { _grpPos = _friendlyPos getPos [_dist, _angle] };

        private _grpSize = [4 + floor random 7, 2] call _scaleOpforCount;  // 4 to 10 units
        private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
        private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
        if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };

        private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
        [_grp] call FAC_applyEnemyScenarioToGroup;
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setBehaviour "AWARE";
            _grp setCombatMode "RED";
            _enemyGroups pushBack _grp;
        };
    };
    [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
    [_taskId, _enemyGroups] call FADE_missionEnt_bindGroups;
    { _x addWaypoint [_friendlyPos, 0] } forEach _enemyGroups;
    private _casUnits = (_friendlyUnits select [0, 6 min count _friendlyUnits]);
    private _friendlyGroup = [_friendlyPos, _sideFriendly, _casUnits] call BIS_fnc_spawnGroup;
    [_taskId, _friendlyGroup] call FADE_missionEnt_registerGroup;
    [_friendlyGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_friendlyGroup] call FADE_attachNightStrobes;
    _friendlyGroup setBehaviour "COMBAT";
    _friendlyGroup setCombatMode "RED";
    private _casCallsign = _friendlyGroup getVariable ["FADE_callsign", "Alpha 1-1"];
    private _casFriendlyCount = count units _friendlyGroup;
    private _casMarkingLine = "Friendly marking on your arrival (within 1 km): green smoke by day, IR strobes at night (NVG).";

    [_player, _taskId, "Provide fire support to friendly forces at the objective. Mission fails if friendly forces are eliminated.", "CAS / Fire Support", _destPos, "attack"] call _fnc_createMissionTask;

    private _markerName = "FADE_cas_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, [_destPos, 100] call _mkrJitter];
    [_taskId, _markerName] call FADE_missionEnt_registerMarker;
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText _operationName;

    private _grid = mapGridPosition _destPos;
    private _brief = format ["CAS / FIRE SUPPORT%1%1Objective area (approx.): Grid %2%1%1Provide on-call fires to support friendly forces in contact. Confirm identification and deconflict before engaging; follow task orders for priority targets.", toString [10], _grid] + _briefGuiTail;
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    private _casSituationHtml = format [
        "<t align='left' color='#FFFFFF'>Supported friendly element: %1.</t><br/><t align='left' color='#FFFFFF'>Friendly strength at objective: %2 soldiers.</t><br/><t align='left' color='#FFFFFF'>%3</t>",
        _casCallsign,
        _casFriendlyCount,
        _casMarkingLine
    ];
    private _casExecutionHtml = format [
        "<t align='left' color='#C0C0C0'>Proceed to AO Grid %1 and support %2 in contact. Prioritise hostiles pressing friendly positions. Mission fails if %2 is eliminated.</t>",
        _grid,
        _casCallsign
    ];
    [
        format ["<t color='#FFFFFF'>AO Grid: %1</t><br/><br/><t color='#FFFFFF'>Support %2 (%3 soldiers) at objective.</t>", _grid, _casCallsign, _casFriendlyCount],
        _casSituationHtml,
        _casExecutionHtml
    ] call _showAssignedHint;
    [_player, "CAS / Fire Support"] call FADE_notifyOthersMissionStarted;

    // Initial air support request from friendly leader at mission start
    [_friendlyGroup, _taskId, _destPos] spawn {
        params ["_grp", "_taskId", "_objPos"];
        sleep 5;
        if (isNull _grp || { count units _grp == 0 }) exitWith {};
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith {};
        private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
        private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        if (count _capable == 0) exitWith {};
        private _speaker = _capable select 0;
        private _grid = mapGridPosition _objPos;
        [_speaker, format ["All callsigns, this is %1. Requesting immediate close air support at Grid %2. Standby for 5-line. Over.", _callsign, _grid]] call FADE_aiSideChat;
    };

    // 5-line CCA: sent independently after a delay, once task is still active.
    // Waits 25 seconds (gives player time to fly to AO), then fires with live enemy data.
    [_friendlyGroup, _taskId, _enemyGroups] spawn {
        params ["_grp", "_taskId", "_enemyGrps"];
        sleep 25;
        if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith {};
        if (isNull _grp || { count units _grp == 0 }) exitWith {};
        private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
        if (count _capable == 0) exitWith {};
        private _speaker = _capable select 0;
        private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];

        // Find nearest living enemy for 5-line data
        private _nearestEnemy = objNull;
        private _nearestDist = 9999;
        {
            { if (alive _x && { (_x distance _speaker) < _nearestDist }) then { _nearestEnemy = _x; _nearestDist = round (_x distance _speaker) } } forEach units _x;
        } forEach _enemyGrps;

        private _targetElev = if (!isNull _nearestEnemy) then { round ((getPosATL _nearestEnemy) select 2) } else { 0 };
        private _hdg = if (!isNull _nearestEnemy) then { round (_speaker getDir _nearestEnemy) } else { 0 };
        private _enemyCount = 0;
        { _enemyCount = _enemyCount + ({ alive _x } count units _x) } forEach _enemyGrps;
        private _enemySize = if (_enemyCount > 10) then { "platoon-sized" } else { if (_enemyCount > 5) then { "squad-sized" } else { "fireteam-sized" } };
        private _targetDesc = format ["hostile infantry, %1, %2 visible", _enemySize, _enemyCount];
        private _remarks = "friendlies marked green smoke/IR strobes; CLEARED HOT when visual";

        [_speaker, format [
            "All callsigns, this is %1. 5-Line CCA. IP own pos, hdg %2. %3m to target. elevation %4m MSL. %5. %6. CLEARED HOT. Over.",
            _callsign, _hdg, _nearestDist, _targetElev, _targetDesc, _remarks
        ]] call FADE_aiSideChat;
    };

    // When player within 1km: night -- radio callsign; day -- green smoke. QRF counter-attack starts from this moment (same as "detected in zone").
    [_friendlyGroup, _player, _taskId, _destPos, _basePos, _enemyUnits, _enemyGroups] spawn {
        params ["_grp", "_player", "_taskId", "_destPos", "_basePos", "_enemyUnits", "_enemyGroups"];
        private _done = false;
        while { !_done && { !isNull _grp } && { count units _grp > 0 } && { !isNull _player } } do {
            sleep 10;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { _done = true };
            private _veh = vehicle _player;
            private _friendlyPos = getPosATL (leader _grp);
            if (_veh distance _friendlyPos < 1000) then {
                private _callsign = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
                private _capable = (units _grp) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } };
                private _speaker = if (count _capable > 0) then { _capable select 0 } else { objNull };
                private _timeMin = (date select 3) * 60 + (date select 4);
                private _isNight = (_timeMin >= 1170 || { _timeMin <= 270 });
                if (_isNight && { isClass (configFile >> "CfgPatches" >> "ace_attach") }) then {
                    if (!isNull _speaker) then {
                        [_speaker, format ["RZ, This is %1. We're in contact. IR strobes active on all units. Over!", _callsign]] call FADE_aiSideChat;
                    };
                } else {
                    "SmokeShellGreen" createVehicle _friendlyPos;
                    if (!isNull _speaker) then {
                        [_speaker, format ["RZ, This is %1. Marking our position with green smoke. Over.", _callsign]] call FADE_aiSideChat;
                    };
                };
                [_taskId, _destPos, _basePos, _enemyUnits, _enemyGroups, -1, true] call FADE_counterAttackStart;
                _done = true;
            };
        };
    };

    private _initialEnemyCount = 0;
    { _initialEnemyCount = _initialEnemyCount + count units _x } forEach _enemyGroups;
    [_taskId, _enemyGroups, _friendlyGroup, _markerName, _player, _initialEnemyCount] spawn {
        params ["_taskId", "_enemyGroups", "_friendlyGroup", "_markerName", "_player", "_initialEnemyCount"];
        private _threshold = _initialEnemyCount * 0.2;
        waitUntil {
            sleep 1;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
            private _friendlyAlive = if (!isNull _friendlyGroup && { count units _friendlyGroup > 0 }) then {
                { alive _x } count units _friendlyGroup
            } else { 0 };
            if (_friendlyAlive == 0) exitWith {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Friendly forces have been eliminated.</t>"] remoteExec ["FADE_showMissionHint", _player];
                true
            };
            private _aliveCount = 0;
            { _aliveCount = _aliveCount + ({ alive _x } count units _x) } forEach _enemyGroups;
            if (_aliveCount < _threshold) exitWith {
                private _capable = if (!isNull _friendlyGroup) then {
                    (units _friendlyGroup) select { alive _x && { !(_x getVariable ["ACE_isUnconscious", false]) } }
                } else { [] };
                if (count _capable > 0) then {
                    private _callsign = _friendlyGroup getVariable ["FADE_callsign", "Alpha 1-1"];
                    [(_capable select 0), format ["This is %1. Hostiles suppressed. Nice work. Out.", _callsign]] call FADE_aiSideChat;
                };
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            false
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_taskId, _friendlyGroup] spawn {
            params ["_taskId", "_friendlyGroup"];
            sleep 60;
            if (!isNull _friendlyGroup) then {
                { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_friendlyGroup getVariable ["FADE_irStrobes", []]);
            };
            if !(missionNamespace getVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false]) then {
                [_taskId, "", false] call FADE_cleanupMissionEntities;
            };
        };
    };
};

