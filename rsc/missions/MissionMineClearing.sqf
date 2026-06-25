// AUTO-EXTRACTED from Missions.sqf  -  run via FADE_runMission_* (compile once)
if (!isServer) exitWith {};
FADE_runMission_MineClearing = {
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
    private _useMines = random 1 < 0.5;
    private _need = if (_useMines) then { 2 + (floor random 4) } else { 1 + (floor random 3) };
    private _minSep = 20;
    private _anchor = if (_fromMapClick && { [_mapAnchor] call FADE_fnc_isValidMapClickPos }) then { +_mapAnchor } else { +_destPos };
    if (count _anchor < 3) then { _anchor set [2, 0] };

    private _sepOkFn = {
        params ["_p", "_list", "_minD"];
        private _ok = true;
        { if ((_p distance2D _x) < _minD) exitWith { _ok = false } } forEach _list;
        _ok
    };

    private _greedyFromPool = {
        params ["_pool", "_have", "_target", "_minD", "_sepOkFn"];
        private _out = +_have;
        {
            if (count _out >= _target) exitWith {};
            private _p = getPosATL _x;
            if (count _p < 2) then { } else {
                if (!(surfaceIsWater _p) && { [_p, _out, _minD] call _sepOkFn }) then { _out pushBack _p };
            };
        } forEach _pool;
        _out
    };

    private _bestChain = [];
    private _radii = [200, 350, 500, 650];
    private _ri = 0;
    while { _ri < count _radii } do {
        private _rad = _radii select _ri;
        _ri = _ri + 1;
        private _roads = _anchor nearRoads _rad;
        if (_roads isEqualTo []) then { } else {
            private _roadsShuffled = _roads call BIS_fnc_arrayShuffle;
            private _maxStarts = (count _roadsShuffled) min 20;
            for "_s" from 0 to (_maxStarts - 1) do {
                private _start = _roadsShuffled select _s;
                private _visited = [];
                private _queue = [_start];
                private _chain = [];
                while { count _chain < _need && count _queue > 0 } do {
                    private _rd = _queue deleteAt 0;
                    if (_rd in _visited) then { } else {
                        _visited pushBack _rd;
                        private _p = getPosATL _rd;
                        if (count _p >= 2 && { !(surfaceIsWater _p) } && { [_p, _chain, _minSep] call _sepOkFn }) then {
                            _chain pushBack _p;
                        };
                        {
                            if (!(_x in _visited)) then { _queue pushBack _x };
                        } forEach (roadsConnectedTo _rd);
                    };
                };
                if (count _chain > count _bestChain) then { _bestChain = +_chain };
            };
        };
    };

    private _positions = +_bestChain;
    if (count _positions > _need) then { _positions resize _need };
    if (count _positions < _need) then {
        private _pool = (_anchor nearRoads 700) call BIS_fnc_arrayShuffle;
        _positions = [_pool, _positions, _need, _minSep, _sepOkFn] call _greedyFromPool;
    };

    if (count _positions < _need) then {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place hazards along roads in this area. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _nPlaced = count _positions;
        private _sx = 0;
        private _sy = 0;
        private _sz = 0;
        { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1); _sz = _sz + (_x param [2, 0]) } forEach _positions;
        private _centerPos = [_sx / _nPlaced, _sy / _nPlaced, _sz / _nPlaced];
        if (surfaceIsWater _centerPos) then { _centerPos = [_sx / _nPlaced, _sy / _nPlaced, _anchor param [2, 0]] };

        private _hazards = [];
        if (_useMines) then {
            private _mineClass = "APERSBoundingMine";
            if (!isClass (configFile >> "CfgVehicles" >> _mineClass)) then { _mineClass = "APERSMine" };
            {
                private _p = +_x;
                if (count _p < 3) then { _p set [2, 0] };
                private _m = createMine [_mineClass, _p, [], 0];
                if (!isNull _m) then { _hazards pushBack _m };
            } forEach _positions;
        } else {
            private _iedClass = "IEDLandBig_F";
            if (!isClass (configFile >> "CfgVehicles" >> _iedClass)) then { _iedClass = "Land_IED_v1_F" };
            {
                private _p = +_x;
                if (count _p < 3) then { _p set [2, 0] };
                private _ied = createVehicle [_iedClass, _p, [], 0, "NONE"];
                if (!isNull _ied) then {
                    _ied setPosATL _p;
                    _ied setDir (random 360);
                    _hazards pushBack _ied;
                };
            } forEach _positions;
        };

        if (count _hazards < _need) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach _hazards;
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn all hazards. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
        } else {
            private _hazardWord = if (_useMines) then {
                if (_need == 1) then { "mine" } else { "mines" }
            } else {
                if (_need == 1) then { "IED" } else { "IEDs" }
            };
            private _taskDescShort = if (_useMines) then {
                format ["Clear all %1 along the route (disarm). Hazards are on the road network near the marker.", _hazardWord]
            } else {
                format ["Locate and disarm or destroy all %1 along the route. Hazards are on the road network near the marker.", _hazardWord]
            };

            [_player, _taskId, _taskDescShort, "Mine Clearing", _centerPos, "destroy"] call _fnc_createMissionTask;

            private _markerName = "FADE_mines_" + _taskId;
            _player setVariable ["FADE_myMissionMarker", _markerName, true];
            private _mkr = createMarker [_markerName, [_centerPos, 30] call _mkrJitter];
            [_taskId, _markerName] call FADE_missionEnt_registerMarker;
            _mkr setMarkerType "mil_warning";
            _mkr setMarkerColor (missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"]);
            _mkr setMarkerText _operationName;

            private _grid = mapGridPosition _centerPos;
            private _threatLine = if (_useMines) then {
                "Intel: anti-personnel mines reported along a short route segment  -  EOD clearance."
            } else {
                "Intel: improvised devices reported along a short route segment  -  treat as live until cleared."
            };
            _player setVariable ["FADE_myMissionBrief", format ["MINE / EOD CLEARANCE%1%1Route (approx.): Grid %2%1%3", toString [10], _grid, _threatLine] + _briefGuiTail, true];

            private _missionHtml = format [
                "<t color='#FFFFFF'>Grid: %1</t><br/><t color='#FFFFFF'>Threat: %2 x %3 on road.</t><br/><br/><t color='#FFFFFF'>Marker: approximate centre of the hazard stretch. Clear all devices.</t>",
                _grid,
                if (_useMines) then { "mines" } else { "IEDs" },
                _need
            ];
            private _situationHtml = format [
                "<t align='left' color='#FFFFFF'>%1</t><br/><br/>%2",
                _threatLine,
                _defaultSituationHintHtml
            ];
            [_missionHtml, _situationHtml] call _showAssignedHint;

            [_player, "Mine Clearing"] call FADE_notifyOthersMissionStarted;

            [_taskId, _hazards, _markerName, _player, _useMines] spawn {
                params ["_taskId", "_hazards", "_markerName", "_player", "_useMines"];
                private _left = 1;
                while { _left > 0 } do {
                    sleep 2;
                    _left = 0;
                    {
                        if (!isNull _x) then {
                            if (_useMines) then {
                                _left = _left + 1;
                            } else {
                                if (alive _x) then { _left = _left + 1 };
                            };
                        };
                    } forEach _hazards;
                };
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                private _doneMsg = if (_useMines) then {
                    "<t size='1.2' color='#90EE90'>MINES CLEARED</t><br/><br/><t color='#E0E0E0'>All mines neutralised.</t>"
                } else {
                    "<t size='1.2' color='#90EE90'>IEDs CLEARED</t><br/><br/><t color='#E0E0E0'>All devices neutralised.</t>"
                };
                [_doneMsg] remoteExec ["FADE_showMissionHint", _player];
                sleep 5;
                [_markerName] call FADE_deleteMarkerSafe;
                if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                [_taskId, 60, _player] call FADE_missionEnt_scheduledCleanup;
            };
        };
    };
};

