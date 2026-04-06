// =============================================================================
// Missions.sqf -- Dynamic mission implementations (runs on server; compiled from initServer FADE_startMission)
// =============================================================================
//
// EXECUTION: Invoked via spawn+compile from FADE_startMission (server). Params from FADE_missionParams
//   (set in the same spawn before compile - avoids cross-player races with execVM queue).
// _missionType: "TroopInsert" | "TroopExtract" | "CAS" | "Cargo" | "HVT" | "Hostage" | "ClearArea" | "InterceptConvoy"
// _destPos: position array [x,y,z] -- from FADE_startMission (Asset Retrieval: within 500 m of a CIV_T_* zone, 1000 m+ from base; others: see initServer)
// _player: player who started the mission (for tasks, hints, cargo seat check). All remoteExec
//   feedback (hint, systemChat) targets _player so only that client receives it.
//
// SCENARIO: Unit/vehicle lists come from missionNamespace (Scenario GUI Apply or initServer defaults).
// All enemy spawns MUST use FADE_enemyUnits (or local list built from missionNamespace + FADE_scenarioEnemyFaction
// fallback) so faction choices in the config GUI are respected. Do not use BIS_fnc_spawnCrew for vehicles - spawn
// driver/gunner/commander from the scenario enemy unit list so crew matches the chosen faction.
// All createVehicle/createGroup/BIS_fnc_spawnGroup run on server; markers and tasks are server-global.
// =============================================================================

// Params from FADE_missionParams (set by FADE_startMission before compile)
if (isNil "FADE_missionParams" || { count FADE_missionParams < 3 }) exitWith {};
FADE_missionParams params ["_missionType", "_destPos", ["_player", objNull]];
if (!isServer) exitWith {};

// Validate mission type (Global + Single types)
private _validTypes = ["TroopInsert", "TroopExtract", "CAS", "Cargo", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "MineClearing", "FindClearIEDs", "Medical", "MedicalKAT", "MASCAS", "MASCASKAT", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation"];
if !(_missionType in _validTypes) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Unknown mission type.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Single source: scenario-applied unit lists (initServer FADE_resolveScenario* helpers)
private _friendlyUnits = [] call FADE_resolveScenarioFriendlyUnits;
private _enemyUnits = [] call FADE_resolveScenarioEnemyUnits;
private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _markerEnemy = missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"];
private _fallbackEnemyInf = +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_TL_F", "O_Soldier_F", "O_Soldier_AR_F"]]);
if (count _friendlyUnits == 0) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No friendly units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Mission-assigned hint is sent per mission type below (formatted, to _player only)
private _taskId = "FADE_" + _missionType + str (floor (time * 1000));
if (!isNull _player) then {
    _player setVariable ["FADE_myMission", _missionType, true];
    _player setVariable ["FADE_myMissionTaskId", _taskId, true];
};
private _operationName = "Operation Iron Resolve";
if (!isNull _player) then {
    private _playerUid = getPlayerUID _player;
    private _globalEntry = missionNamespace getVariable ["FADE_globalMission", []];
    if (
        count _globalEntry >= 5 &&
        { (_globalEntry param [0, ""]) == _missionType } &&
        {
            (_globalEntry param [1, objNull]) == _player ||
            { (_globalEntry param [3, ""]) == _playerUid }
        }
    ) then {
        _operationName = _globalEntry param [4, _operationName];
    } else {
        private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
        private _singleIdx = _singleList findIf {
            (_x param [0, ""]) == _missionType &&
            {
                (_x param [1, objNull]) == _player ||
                { (_x param [3, ""]) == _playerUid }
            }
        };
        if (_singleIdx >= 0) then {
            _operationName = (_singleList select _singleIdx) param [4, _operationName];
        };
    };
};
private _operationNameUpper = toUpper _operationName;
private _showAssignedHint = {
    params ["_detailsHtml"];
    [format [
        "<t size='1.3' color='#FFD700'>MISSION ASSIGNED</t><br/><br/><t size='1.1' color='#E0E0E0'>%1</t><br/><br/>%2",
        _operationNameUpper,
        _detailsHtml
    ]] remoteExec ["FADE_showMissionHint", _player];
};
private _basePos = FADE_basePos;

// Refine position: LZ missions use small refinement; HVT/ClearArea/InterceptConvoy handle position themselves
private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
if (_missionType != "HVT" && { _missionType != "Hostage" } && { _missionType != "ClearArea" } && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "SearchDestroy" } && { _missionType != "Operation" } && { _missionType != "AssetRetrieval" }) then {
    private _refineMax = if (_needsLZ) then { 10 } else { 50 };
    private _refineObj = if (_needsLZ) then { 15 } else { 5 };
    _destPos = [_destPos, 0, _refineMax, _refineObj, 0, 0.5, 0, [], _destPos] call BIS_fnc_findSafePos;
};
if (count _destPos < 2 && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" } && { _missionType != "Operation" }) exitWith {
    if (!isNull _player) then { _player setVariable ["FADE_myMission", "", true] };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No valid area of operations found.</t>"] remoteExec ["FADE_showMissionHint", _player];
};

// Unit count: use player's vehicle cargo seats if in a heli, else default 6
private _unitCount = 6;
if (!isNull _player) then {
    private _veh = vehicle _player;
    if (_veh != _player && { _veh isKindOf "Helicopter" }) then {
        _unitCount = ([_veh] call FADE_getCargoSeats) max 1;
    };
};
private _unitClasses = (_friendlyUnits select [0, _unitCount min count _friendlyUnits]);
private _baseClass = _friendlyUnits select 0;
for "_i" from (count _unitClasses) to (_unitCount - 1) do {
    _unitClasses pushBack _baseClass;
};

// Task: BI task framework only - one create, owner = starter, ASSIGNED (P4: do not also create
// for other players / whole side; the old pattern CREATED for _others + ASSIGNED for _player
// gave everyone the task). No remoteExec / client helpers (some builds reject code in remoteExec).
private _fnc_createMissionTask = {
    params ["_player", "_taskId", "_desc", "_title", "_pos", "_taskType"];
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    if (!isNull _player) then {
        [_player, _taskId, [_desc, _title, ""], _pos, "ASSIGNED", 1, true, _taskType, true] call BIS_fnc_taskCreate;
    } else {
        [_sf, _taskId, [_desc, _title, ""], _pos, "CREATED", 1, false, _taskType, true] call BIS_fnc_taskCreate;
    };
};

// Scale OPFOR counts using scenario population setting.
private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {
    params ["_baseCount", ["_minCount", 1], ["_maxCount", -1]];
    private _base = floor (_baseCount max 0);
    if (_base <= 0) exitWith { 0 };
    private _scaled = _base max _minCount;
    if (_maxCount >= 0 && { _scaled > _maxCount }) then { _scaled = _maxCount };
    _scaled
}];

// Attach an IR strobe to every living unit in _grp if it is night (19:30-04:30) and ACE3 is loaded.
// Strobes are stored in FADE_irStrobes group variable so cleanup can delete them.
// Called immediately after BIS_fnc_spawnGroup for any friendly group.
FADE_attachNightStrobes = {
    params ["_grp"];
    private _timeMin = (date select 3) * 60 + (date select 4);
    if !(_timeMin >= 1170 || { _timeMin <= 270 }) exitWith {};
    if !(isClass (configFile >> "CfgPatches" >> "ace_attach")) exitWith {};
    private _irVehClass = getText (configFile >> "CfgWeapons" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable");
    if (_irVehClass == "") then { _irVehClass = getText (configFile >> "CfgMagazines" >> "ACE_IR_Strobe_Item" >> "ACE_Attachable") };
    if (_irVehClass == "") exitWith {};
    private _strobes = [];
    {
        if (alive _x) then {
            private _s = _irVehClass createVehicle [0,0,0];
            _s attachTo [_x, [0.07, -0.06, 0.085], "leftshoulder"];
            _strobes pushBack _s;
        };
    } forEach units _grp;
    _grp setVariable ["FADE_irStrobes", _strobes];
};

// -----------------------------------------------------------------------------
// AREA OF OPERATIONS -- 2 km zone, 3 capture points, BLUFOR vs OPFOR, JTAC
// -----------------------------------------------------------------------------
if (_missionType == "AreaOfOperations") exitWith {
    [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits] spawn {
        params ["_player", "_destPos", "_taskId", "_basePos", "_friendlyUnits", "_enemyUnits"];
        FADE_aoParams = [_player, _destPos, _taskId, _basePos, _friendlyUnits, _enemyUnits];
        call compile preprocessFileLineNumbers "rsc\AOMission.sqf";
    };
};

// -----------------------------------------------------------------------------
// 0b. OPERATION -- Multi-zone capture (global); see rsc\OperationMission.sqf
// Spawn + compile (same pattern as AreaOfOperations): isolates locals from this file.
// Inline call compile shared scope with Missions.sqf and broke _allGroups / retreat registration (RPT: foreach Bool).
// -----------------------------------------------------------------------------
if (_missionType == "Operation") exitWith {
    [_player, _taskId, _basePos, _enemyUnits] spawn {
        params ["_player", "_taskId", "_basePos", "_enemyUnits"];
        FADE_operationParams = [_player, _taskId, _basePos, _enemyUnits];
        call compile preprocessFileLineNumbers "rsc\OperationMission.sqf";
    };
};

// -----------------------------------------------------------------------------
// 1. TROOP INSERT -- Spawn friendly AI at B_SP_*, create task to insert at M_LOC_*
// -----------------------------------------------------------------------------
if (_missionType == "TroopInsert") exitWith {
    if (count FADE_bSpPoints == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No spawn points. Configure B_SP_1/2/3 in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _spawnTrigger = selectRandom FADE_bSpPoints;
    if (isNull _spawnTrigger) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No spawn points. Configure B_SP_1/2/3 in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _spawnPos = position _spawnTrigger;

    private _group = [_spawnPos, _sideFriendly, _unitClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group setBehaviour "SAFE";
    _group setCombatMode "GREEN";

    [_player, _taskId, "Insert the squad at the marked LZ.", "Troop Insert", _destPos, "move"] call _fnc_createMissionTask;

    // Create marker for players
    private _markerName = "FADE_insert_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText "LZ Insert";

    private _grid = mapGridPosition _destPos;
    private _brief = format ["TROOP INSERT%1%1PICKUP: Base (squad at B_SP)%1TARGET: LZ Grid %2%1%1Pick up squad at base. Fly to marked LZ. Land to disembark.%1%1Complete when squad has disembarked at LZ.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>LZ Grid: %1</t><br/><br/><t color='#C0C0C0'>RTB. Pick up squad at base. Proceed to LZ. Land to disembark.</t>", _grid]] call _showAssignedHint;
    [_player, "Troop Insert"] call FADE_notifyOthersMissionStarted;

    [_missionType, _group, _player, _spawnPos, _destPos, _taskId, _markerName] spawn {
        params ["_missionType", "_group", "_player", "_spawnPos", "_destPos", "_taskId", "_markerName"];
        FADE_transportParams = [_missionType, _group, _player, _spawnPos, _destPos, _taskId, _markerName];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2. TROOP EXTRACT -- Spawn friendly AI at M_LOC_*, create task to extract to base
// 50% chance: 1-5 enemy groups 500-2000m from pickup, moving to engage; else quiet pickup (SAFE)
// -----------------------------------------------------------------------------
if (_missionType == "TroopExtract") exitWith {
    // Pickup group: 2-10 units regardless of player's vehicle
    private _pickupCount = 2 + floor random 9;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 0, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
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
                _candidate = [_candidate, 0, 30, 3, 0, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
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
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText "Pickup Zone";

    private _grid = mapGridPosition _destPos;
    private _brief = format ["TROOP EXTRACT%1%1PICKUP: Grid %2 (marked on map)%1TARGET: Base (RTB)%1PAX: %3 personnel for extraction%1%1Fly to pickup zone. Land to load squad. Return to base and land.%1%1Complete when squad has disembarked at base.", toString [10], _grid, _pickupCount];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>RZ Grid: %1</t><br/><t color='#FFCC00'>PAX: %2 personnel</t><br/><br/><t color='#C0C0C0'>Proceed to pickup zone. Land to load squad. RTB once loaded.</t>", _grid, _pickupCount]] call _showAssignedHint;
    [_player, "Troop Extract"] call FADE_notifyOthersMissionStarted;

    private _teQrfPos = +_destPos;
    if (count _teQrfPos < 3) then { _teQrfPos = [(_teQrfPos select 0), (_teQrfPos select 1), 0] };
    [_taskId, _teQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2b. CASEVAC -- Troop extract; squad has KIA and ACE injuries before pickup
// -----------------------------------------------------------------------------
if (_missionType == "CASEVAC") exitWith {
    private _pickupCount = 2 + floor random 9;
    private _pickupClasses = (_friendlyUnits select [0, _pickupCount min count _friendlyUnits]);
    for "_i" from (count _pickupClasses) to (_pickupCount - 1) do { _pickupClasses pushBack (_friendlyUnits select 0) };

    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 0, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
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
                _candidate = [_candidate, 0, 30, 3, 0, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
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

    [_player, _taskId, "CASEVAC: extract casualties and return to base.", "CASEVAC", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_casevac_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText "CASEVAC";

    private _grid = mapGridPosition _destPos;
    private _living = { alive _x } count units _group;
    private _brief = format ["CASEVAC%1%1PICKUP: Grid %2 (marked on map)%1TARGET: Base (RTB)%1PAX: %3 alive (some KIA on site; remainder need CASEVAC)%1%1Land to load survivors. RTB and land at base.%1%1Complete when squad has disembarked at base.", toString [10], _grid, _living];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>RZ Grid: %1</t><br/><t color='#FFCC00'>PAX: %2 (wounded)</t><br/><br/><t color='#C0C0C0'>Extract and RTB.</t>", _grid, _living]] call _showAssignedHint;
    [_player, "CASEVAC"] call FADE_notifyOthersMissionStarted;

    private _cvQrfPos = +_destPos;
    if (count _cvQrfPos < 3) then { _cvQrfPos = [(_cvQrfPos select 0), (_cvQrfPos select 1), 0] };
    [_taskId, _cvQrfPos, _basePos, _enemyUnits, _enemyGroups, -1] call FADE_counterAttackStart;

    ["CASEVAC", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2c. CSAR -- Downed helo wreck; single survivor; extract like Troop Extract
// -----------------------------------------------------------------------------
if (_missionType == "CSAR") exitWith {
    private _pickupClasses = [_friendlyUnits select 0];
    private _wpPos = _destPos getPos [10, random 360];
    _wpPos = [_wpPos, 0, 15, 2, 0, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
    if (!(_wpPos isEqualType [])) then { _wpPos = _destPos getPos [10, random 360] };
    if ((_wpPos isEqualType []) && { count _wpPos < 2 }) then { _wpPos = _destPos getPos [10, random 360] };
    // BIS_fnc_findSafePos can return [x,y] only; setPosATL / createVehicle expect ATL with Z
    if ((_wpPos isEqualType []) && { count _wpPos >= 2 && { count _wpPos < 3 } }) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
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
    private _wreckClass = selectRandom _csarWreckOk;
    private _wreck = createVehicle [_wreckClass, _wpPos, [], 0, "NONE"];
    _wreck setPosATL _wpPos;
    _wreck setDir (random 360);
    missionNamespace setVariable ["FADE_csarWreck_" + _taskId, _wreck];

    private _survPos = _wreck getPos [10, random 360];
    _survPos = [_survPos, 0, 8, 2, 0, 0.3, 0, [], _survPos] call BIS_fnc_findSafePos;
    if (!(_survPos isEqualType [])) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos < 2 }) then { _survPos = getPosATL _wreck };
    if ((_survPos isEqualType []) && { count _survPos >= 2 && { count _survPos < 3 } }) then { _survPos = [(_survPos select 0), (_survPos select 1), 0] };
    private _group = [_survPos, _sideFriendly, _pickupClasses] call BIS_fnc_spawnGroup;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    private _crashCenter = getPosATL _wreck;
    if (count _crashCenter < 3) then { _crashCenter = [(_crashCenter select 0), (_crashCenter select 1), 0] };
    // Patrol inside 500 m of crash; STEALTH like a survivor evading
    while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
    private _nSurvWp = 4 + floor random 3;
    for "_i" from 0 to (_nSurvWp - 1) do {
        private _wPos = _crashCenter getPos [random 500, random 360];
        _wPos = [_wPos, 0, 12, 3, 0, 0.35, 0, [], _wPos] call BIS_fnc_findSafePos;
        if (!(_wPos isEqualType []) || { count _wPos < 2 }) then { _wPos = _crashCenter getPos [random 500, random 360] };
        if (count _wPos < 3) then { _wPos = [(_wPos select 0), (_wPos select 1), 0] };
        if ((_wPos distance2D _crashCenter) > 500) then { _wPos = _crashCenter getPos [200 + random 300, random 360] };
        private _wp = _group addWaypoint [_wPos, _i];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
    };
    private _lastSurvWp = (count waypoints _group) - 1;
    if (_lastSurvWp >= 0) then { [_group, _lastSurvWp] setWaypointType "CYCLE" };
    _group setBehaviour "STEALTH";
    _group setCombatMode "GREEN";
    _group setSpeedMode "LIMITED";

    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    {
        if (_useACE && _aceHasAddDamage) then {
            private _p = selectRandom ["Body", "LeftLeg", "RightLeg"];
            [_x, 0.18 + random 0.2, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (_aceHasAddWound) then { [_x, toLower _p, ["VelocityWound", 1, 1, 0.4]] call ace_medical_fnc_addWound };
        } else {
            _x setDamage (0.25 + random 0.2);
        };
    } forEach units _group;

    private _enemyGroups = [];
    if (random 1 < 0.5) then {
        private _numEnemyGroups = [1 + floor random 4, 1] call _scaleOpforCount;
        private _minDistFromBase = 1000;
        for "_g" from 0 to (_numEnemyGroups - 1) do {
            private _grpPos = [];
            for "_try" from 0 to 12 do {
                private _angle = random 360;
                private _dist = 150 + random 350;
                private _candidate = _crashCenter getPos [_dist, _angle];
                _candidate = [_candidate, 0, 20, 3, 0, 0.4, 0, [], _candidate] call BIS_fnc_findSafePos;
                if (count _candidate < 2) then { _candidate = _crashCenter getPos [_dist, _angle] };
                if (count _candidate < 3) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
                if ((_candidate distance2D _crashCenter) <= 500 && { (_candidate distance _basePos) >= _minDistFromBase }) exitWith { _grpPos = _candidate };
            };
            if (count _grpPos < 2) then {
                private _fallback = _crashCenter getPos [250 + random 200, random 360];
                if (count _fallback < 3) then { _fallback = [(_fallback select 0), (_fallback select 1), 0] };
                _grpPos = _fallback;
            };
            private _grpSize = [3 + floor random 5, 2] call _scaleOpforCount;
            private _shuffled = _enemyUnits call BIS_fnc_arrayShuffle;
            private _grpUnits = (_shuffled select [0, _grpSize min count _shuffled]);
            if (count _grpUnits == 0) then { _grpUnits = [_enemyUnits select 0] };
            private _grp = [_grpPos, _sideEnemy, _grpUnits] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            _grp setCombatMode "YELLOW";
            _grp setSpeedMode "LIMITED";
            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
            private _nEgWp = 3 + floor random 3;
            for "_i" from 0 to (_nEgWp - 1) do {
                private _wPos = _crashCenter getPos [random 500, random 360];
                _wPos = [_wPos, 0, 15, 3, 0, 0.4, 0, [], _wPos] call BIS_fnc_findSafePos;
                if (!(_wPos isEqualType []) || { count _wPos < 2 }) then { _wPos = _crashCenter getPos [random 500, random 360] };
                if (count _wPos < 3) then { _wPos = [(_wPos select 0), (_wPos select 1), 0] };
                if ((_wPos distance2D _crashCenter) > 500) then { _wPos = _crashCenter getPos [150 + random 350, random 360] };
                private _ewp = _grp addWaypoint [_wPos, _i];
                _ewp setWaypointType "MOVE";
                _ewp setWaypointSpeed "LIMITED";
            };
            private _lastEg = (count waypoints _grp) - 1;
            if (_lastEg >= 0) then { [_grp, _lastEg] setWaypointType "CYCLE" };
            private _ldrSurv = leader _group;
            if (!isNull _ldrSurv) then { { _x reveal _ldrSurv } forEach units _grp };
            _enemyGroups pushBack _grp;
        };
        [_enemyGroups, _basePos] call FADE_registerEnemyRetreat;
    };

    [_player, _taskId, "CSAR: recover the survivor at the crash site and RTB.", "CSAR", _destPos, "move"] call _fnc_createMissionTask;

    private _markerName = "FADE_csar_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_pickup";
    _marker setMarkerColor _markerFriendly;
    _marker setMarkerText "CSAR";

    private _grid = mapGridPosition _destPos;
    private _brief = format ["CSAR%1%1PICKUP: Grid %2 — downed aircraft%1TARGET: Base (RTB)%1%1Land at the survivor's position. Load and RTB.%1%1Complete when survivor has disembarked at base.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>CSAR Grid: %1</t><br/><br/><t color='#C0C0C0'>Survivor at crash site.</t>", _grid]] call _showAssignedHint;
    [_player, "CSAR"] call FADE_notifyOthersMissionStarted;

    [_taskId, _crashCenter, _basePos, _enemyUnits, _enemyGroups, 500] call FADE_counterAttackStart;

    // 1 km: survivor sideChat + grid; 500 m: green smoke (pickup uses moving survivor, not static _destPos smoke)
    [_group, _taskId] spawn {
        params ["_group", "_taskId"];
        private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
        private _didRadio1k = false;
        private _didSmoke500 = false;
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
                    [_ldr, format ["This is %1. Mayday — holding near Grid %2. Need immediate pickup. Over.", _cs, _grid]] call FADE_aiSideChat;
                };
                if (!_didSmoke500 && { _minD <= 500 }) then {
                    _didSmoke500 = true;
                    "SmokeShellGreen" createVehicle _posLdr;
                    private _cs2 = _group getVariable ["FADE_callsign", "Survivor"];
                    [_ldr, format ["This is %1. Marking position with green smoke. Over.", _cs2]] call FADE_aiSideChat;
                };
            };
        };
    };

    ["CSAR", _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups] spawn {
        params ["_missionType", "_group", "_player", "_destPos", "_basePos", "_taskId", "_markerName", "_enemyGroups"];
        FADE_transportParams = [_missionType, _group, _player, _destPos, _basePos, _taskId, _markerName, _enemyGroups];
        call compile preprocessFileLineNumbers "rsc\TroopTransport.sqf";
    };
};

// -----------------------------------------------------------------------------
// 2d. ASSET RETRIEVAL -- Intel at small site; secure then RTB to base
// -----------------------------------------------------------------------------
if (_missionType == "AssetRetrieval") exitWith {
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _enemyGroups = [];
    for "_g" from 0 to 1 do {
        private _angle = random 360;
        private _dist = 80 + random 120;
        private _grpPos = [(_destPos select 0) + _dist * (cos _angle), (_destPos select 1) + _dist * (sin _angle), 0];
        _grpPos = [_grpPos, 0, 25, 3, 0, 0.4, 0, [], _grpPos] call BIS_fnc_findSafePos;
        if (count _grpPos < 2) then { _grpPos = _destPos };
        private _grpSize = [3 + floor random 4, 2] call _scaleOpforCount;
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

    private _comp = [
        ["Land_CampingTable_F", 4, 0, 0],
        ["Land_CampingChair_V2_F", 5, 90, 0],
        ["Land_PlasticCase_01_small_gray_F", 3, 180, 0]
    ];
    private _compObjs = [];
    {
        _x params ["_cls", "_dist", "_angle", "_dirObj"];
        private _pos = [(_destPos select 0) + _dist * (cos _angle), (_destPos select 1) + _dist * (sin _angle), (_destPos param [2, 0])];
        _pos = [_pos, 0, 2, 0, 0, 0.3, 0, [], _pos] call BIS_fnc_findSafePos;
        if (_pos isEqualType [] && { count _pos >= 2 }) then {
            _pos = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            private _obj = createVehicle [_cls, _pos, [], 0, "NONE"];
            _obj setDir (_angle + _dirObj);
            _obj setPosATL _pos;
            _compObjs pushBack _obj;
        };
    } forEach _comp;

    private _intelObj = objNull;
    {
        if (typeOf _x == "Land_PlasticCase_01_small_gray_F") exitWith { _intelObj = _x };
    } forEach _compObjs;

    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
    if (!isNull _intelObj) then {
        _intelObj addAction [
            "Secure intel package",
            {
                (_this select 3) params ["_taskId"];
                [_taskId, _this select 0] remoteExec ["FADE_assetIntelTakeServer", 2];
            },
            [_taskId],
            1.5,
            true,
            true,
            "",
            "(_this distance _target) < 3 && { alive _this }",
            3
        ];
    };

    missionNamespace setVariable ["FADE_assetEntities_" + _taskId, _enemyGroups];
    missionNamespace setVariable ["FADE_assetObjects_" + _taskId, _compObjs];
    missionNamespace setVariable ["FADE_assetAborted_" + _taskId, false];

    [_player, _taskId, "Secure intel at the site, then return to base.", "Asset Retrieval", _destPos, "search"] call _fnc_createMissionTask;

    private _markerName = "FADE_asset_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorYellow";
    _marker setMarkerText "Intel";

    private _grid = mapGridPosition _destPos;
    private _brief = format ["ASSET RETRIEVAL%1%1SITE: Grid %2%1%1Clear hostiles. Use scroll action on the case to secure intel. RTB within 150 m of base with intel secured.%1", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Grid: %1</t><br/><br/><t color='#C0C0C0'>Secure intel, then RTB.</t>", _grid]] call _showAssignedHint;
    [_player, "Asset Retrieval"] call FADE_notifyOthersMissionStarted;

    private _arQrfPos = +_destPos;
    if (count _arQrfPos < 3) then { _arQrfPos = [(_arQrfPos select 0), (_arQrfPos select 1), 0] };
    [_taskId, _arQrfPos, _basePos, _enemyUnits, _enemyGroups, 320] call FADE_counterAttackStart;

    [_taskId, _destPos, _basePos, _markerName, _player, _enemyGroups, _compObjs] spawn {
        params ["_taskId", "_destPos", "_basePos", "_markerName", "_player", "_enemyGroups", "_compObjs"];
        private _baseDist = 150;
        private _timeout = 1200;
        private _t0 = time;
        waitUntil {
            sleep 2;
            if (missionNamespace getVariable ["FADE_assetAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (time - _t0 > _timeout) exitWith { true };
            if (
                missionNamespace getVariable ["FADE_assetIntelTaken_" + _taskId, false] &&
                { !isNull _player } &&
                { alive _player } &&
                { (_player distance _basePos) <= _baseDist }
            ) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#90EE90'>MISSION COMPLETE</t><br/><br/><t color='#E0E0E0'>Intel secured and returned to base.</t>"] remoteExec ["FADE_showMissionHint", _player];
                true
            };
            false
        };
        if ((time - _t0 > _timeout) && { (_taskId call BIS_fnc_taskState) == "ASSIGNED" }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
            ["<t size='1.2' color='#FFAA00'>MISSION ENDED</t><br/><br/><t color='#E0E0E0'>Time limit.</t>"] remoteExec ["FADE_showMissionHint", _player];
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetObjects_" + _taskId, nil];
        missionNamespace setVariable ["FADE_assetAborted_" + _taskId, nil];
        sleep 45;
        { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _enemyGroups;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _compObjs;
    };
};

// -----------------------------------------------------------------------------
// 3. CAS / FIRE SUPPORT -- Spawn 1-3 enemy infantry groups (min 750m from friendlies, advancing on friendlies);
//    Friendly infantry only. Friendlies mark with green smoke + sideChat when player within 1km.
// -----------------------------------------------------------------------------
if (_missionType == "CAS") exitWith {
    if (count _enemyUnits == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Friendly position first (200-400m from objective center); enemies spawn min 750m from friendlies
    private _friendlyPos = [_destPos, 200, 400, 5, 0, 0, 0, [], _destPos] call BIS_fnc_findSafePos;
    private _minEnemyDistFromFriendlies = 750;
    private _numGroups = [2 + floor random 3, 1] call _scaleOpforCount;  // 2 to 4 groups
    private _enemyGroups = [];
    private _groupOffset = 30;  // meters between group spawn rings

    for "_g" from 0 to (_numGroups - 1) do {
        private _angle = random 360;
        private _dist = _minEnemyDistFromFriendlies + (_groupOffset * _g) + (random 80);  // 750m+ from friendlies
        private _grpPos = _friendlyPos getPos [_dist, _angle];
        _grpPos = [_grpPos, 0, 25, 3, 0, 0.4, 0, [], _grpPos] call BIS_fnc_findSafePos;
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
    { _x addWaypoint [_friendlyPos, 0] } forEach _enemyGroups;
    private _casUnits = (_friendlyUnits select [0, 6 min count _friendlyUnits]);
    private _friendlyGroup = [_friendlyPos, _sideFriendly, _casUnits] call BIS_fnc_spawnGroup;
    [_friendlyGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_friendlyGroup] call FADE_attachNightStrobes;
    _friendlyGroup setBehaviour "COMBAT";
    _friendlyGroup setCombatMode "RED";

    [_player, _taskId, "Provide fire support to friendly forces at the objective. Mission fails if friendly forces are eliminated.", "CAS / Fire Support", _destPos, "attack"] call _fnc_createMissionTask;

    private _markerName = "FADE_cas_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText "CAS Objective";

    private _grid = mapGridPosition _destPos;
    private _brief = format ["CAS / FIRE SUPPORT%1%1TARGET: AO Grid %2 (marked on map)%1%1Proceed to objective. Friendlies will radio their position when you are within 1 km -- green smoke by day, IR strobes at night (NVG required). Engage hostiles advancing on friendly forces.%1%1Complete when less than 20% of enemy remain. FAIL if all friendly forces are eliminated. No time limit.", toString [10], _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>AO Grid: %1</t><br/><br/><t color='#C0C0C0'>Proceed to objective. Engage hostiles. Support friendly forces.</t>", _grid]] call _showAssignedHint;
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

    // When player within 1km: night -- radio callsign; day -- green smoke.
    [_friendlyGroup, _player, _taskId] spawn {
        params ["_grp", "_player", "_taskId"];
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
        [_enemyGroups, _friendlyGroup] spawn {
            params ["_enemyGroups", "_friendlyGroup"];
            sleep 60;
            { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _enemyGroups;
            if (!isNull _friendlyGroup) then {
                { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_friendlyGroup getVariable ["FADE_irStrobes", []]);
                { deleteVehicle _x } forEach units _friendlyGroup;
                deleteGroup _friendlyGroup;
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 4. CARGO / RESUPPLY -- Spawn cargo at base; spawn small camp + garrison at LZ;
//    player lands at camp → AI walks to vehicle → animation + sideChat → 5s → complete; 60s cleanup
// -----------------------------------------------------------------------------
if (_missionType == "Cargo") exitWith {
    if (isNil "FADE_cargoClasses" || { count FADE_cargoClasses == 0 }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No cargo classes configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _cargoClass = selectRandom FADE_cargoClasses;
    if (isNil "_cargoClass" || { _cargoClass == "" }) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Invalid cargo class.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Spawn cargo at CargoPoint_1 marker; findSafePos avoids clipping with vehicles
    private _cargoCenter = getMarkerPos "CargoPoint_1";
    if (_cargoCenter isEqualTo [0,0,0]) then { _cargoCenter = _basePos };
    if (count _cargoCenter < 3) then { _cargoCenter = [(_cargoCenter select 0), (_cargoCenter select 1), 0] };
    private _cargoPos = [_cargoCenter, 0, 8, 4, 0, 0.3, 0, [], _cargoCenter] call BIS_fnc_findSafePos;
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
        _pos = [_pos, 0, 2, 0, 0, 0.3, 0, [], _pos] call BIS_fnc_findSafePos;
        if (_pos isEqualType [] && { count _pos >= 2 }) then {
            _pos = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            private _obj = createVehicle [_class, _pos, [], 0, "NONE"];
            _obj setDir (_angle + _dirObj);
            _obj setPosATL _pos;
            if (surfaceIsWater _pos) then { _obj setPosATL [_pos select 0, _pos select 1, 0] } else { _obj setVectorUp surfaceNormal _pos };
            _campObjects pushBack _obj;
        };
    } forEach _campComposition;

    // Single receiving unit (the one who walks to the helicopter and confirms unload)
    private _receiverClass = _friendlyUnits select 0;
    private _garrisonPos = [_destPos, 0, 8, 2, 0, 0.3, 0, [], _destPos] call BIS_fnc_findSafePos;
    if (count _garrisonPos < 2) then { _garrisonPos = _destPos };
    private _garrisonGroup = [_garrisonPos, _sideFriendly, [_receiverClass]] call BIS_fnc_spawnGroup;
    [_garrisonGroup] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    _garrisonGroup setBehaviour "SAFE";
    _garrisonGroup setCombatMode "GREEN";
    {
        private _p = [_garrisonPos, 0, 3, 0, 0, 0.2, 0, [], _garrisonPos] call BIS_fnc_findSafePos;
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
        _psp = [_psp, 0, 15, 3, 0, 0.3, 0, [], _psp] call BIS_fnc_findSafePos;
        if (count _psp < 2) then { _psp = _destPos };
        private _pg_grp = [_psp, _sideFriendly, _patrolClasses] call BIS_fnc_spawnGroup;
        [_pg_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
        _pg_grp setBehaviour "SAFE";
        _pg_grp setCombatMode "GREEN";
        for "_w" from 0 to 3 do {
            private _wa = _w * 90 + (random 30);
            private _wd = 80 + random 120;
            private _wpPos = [(_destPos select 0) + _wd * (cos _wa), (_destPos select 1) + _wd * (sin _wa), 0];
            _wpPos = [_wpPos, 0, 10, 2, 0, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
            if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                private _wp = _pg_grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                if (_w == 3) then { _wp setWaypointType "CYCLE" };
            };
        };
        _cargoPatrolGroups pushBack _pg_grp;
    };

    [_player, _taskId, "Deliver cargo to the camp. Land at the camp for the receiving party to unload.", "Cargo / Resupply", _destPos, "box"] call _fnc_createMissionTask;

    private _markerName = "FADE_cargo_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _destPos];
    _marker setMarkerType "loc_bunker";
    _marker setMarkerColor "ColorYellow";
    _marker setMarkerText "Resupply Camp";

    // Cargo box pickup marker - only visible while this mission is active
    private _cargoPickupMarkerName = "FADE_cargoPickup_" + _taskId;
    private _cargoPickupMarker = createMarker [_cargoPickupMarkerName, _cargoPos];
    _cargoPickupMarker setMarkerType "mil_box";
    _cargoPickupMarker setMarkerColor "ColorYellow";
    _cargoPickupMarker setMarkerText "Cargo Box";

    private _grid = mapGridPosition _destPos;
    private _cargoGrid = mapGridPosition _cargoPos;
    private _brief = format ["CARGO / RESUPPLY%1%1TARGET: Camp Grid %2 (marked on map)%1%1A cargo box is available at Grid %3 (marked) if you want to practice sling load; bringing it to camp is optional. To complete the mission, fly to the camp and land -- the receiving party will confirm unload.%1%1Complete by landing at camp.", toString [10], _grid, _cargoGrid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Camp Grid: %1</t><br/><t color='#AAAAAA'>Cargo Box: Grid %2 (optional sling load)</t><br/><br/><t color='#C0C0C0'>Fly to camp and land to complete. Delivering the box is optional.</t>", _grid, _cargoGrid]] call _showAssignedHint;
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
                        _approachPos = [_approachPos, 0, 2, 0, 0, 0.3, 0, [], _approachPos] call BIS_fnc_findSafePos;
                        if (_approachPos isEqualType [] && { count _approachPos >= 2 }) then {
                            _approachPos = [(_approachPos select 0), (_approachPos select 1), (_approachPos param [2, 0])];
                            _receivingUnit doMove _approachPos;
                        } else {
                            _receivingUnit doMove (getPos _targetVeh);
                        };
                    } else {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_markerName] call FADE_deleteMarkerSafe;
                        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                            params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                            sleep 60;
                            { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                            if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                            if (!isNull _cargo) then { deleteVehicle _cargo };
                            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                        };
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
                    [_markerName] call FADE_deleteMarkerSafe;
                    [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                    if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                    [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                        params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                        sleep 60;
                        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                        if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                        if (!isNull _cargo) then { deleteVehicle _cargo };
                        { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                    };
                    _waitDone = true;
                } else {
                    if (time - _unloadStartTime > 25) then {
                        [_receivingUnit, format ["This is %1. Confirm drop-off. Out.", _callsign]] call FADE_aiSideChat;
                        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                        [_markerName] call FADE_deleteMarkerSafe;
                        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
                        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
                        [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                            params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                            sleep 60;
                            { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                            if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                            if (!isNull _cargo) then { deleteVehicle _cargo };
                            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
                        };
                        _waitDone = true;
                    };
                };
            };

            _waitDone
        };

        if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_markerName] call FADE_deleteMarkerSafe;
        [_cargoPickupMarkerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        if ((_taskId call BIS_fnc_taskState) != "SUCCEEDED") then {
            [_campObjects, _garrisonGroup, _cargo, _cargoPatrolGroups] spawn {
                params ["_campObjects", "_garrisonGroup", "_cargo", "_pgGrps"];
                sleep 60;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                if (!isNull _garrisonGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _garrisonGroup; deleteGroup _garrisonGroup };
                if (!isNull _cargo) then { deleteVehicle _cargo };
                { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _pgGrps;
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 5. HVT -- High Value Target in urban building; guards (ambient combat anim) + patrols; complete on kill or capture at base
// -----------------------------------------------------------------------------
if (_missionType == "HVT") exitWith {
    private _hvtMinSlots = 10;
    private _buildRadius = 250;
    private _patrolRadius = 250;
    private _baseDistForComplete = 80;
    private _minDistHVT = 1000;

    private _targetBuilding = objNull;
    private _attempt = 0;
    while { _attempt < 15 } do {
        _attempt = _attempt + 1;
        if (_attempt > 1) then {
            _destPos = [_minDistHVT] call FADE_findMissionPosUrban;
            if (count _destPos >= 2) then { _destPos = [(_destPos select 0), (_destPos select 1), (_destPos param [2, 0])] };
        };
        if (count _destPos < 2) exitWith {};
        private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
        {
            private _bps = _x buildingPos -1;
            if (count _bps >= _hvtMinSlots) exitWith { _targetBuilding = _x };
        } forEach _buildings;
        if (!isNull _targetBuilding) exitWith {};
    };

    if (isNull _targetBuilding) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No suitable building (10+ positions) in any urban area. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _bpos = _targetBuilding buildingPos -1;
    if (count _bpos < _hvtMinSlots) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Building has insufficient positions.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _officerClasses = _enemyUnits select { ("officer" in (toLower _x)) };
    private _hvtClass = if (count _officerClasses > 0) then { selectRandom _officerClasses } else { if (count _enemyUnits > 0) then { selectRandom _enemyUnits } else { selectRandom _fallbackEnemyInf } };
    private _guardCount = [6 + floor random 4, 2] call _scaleOpforCount;
    private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
    for "_i" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
    private _patrolGroupCount = [1 + floor random 3, 1] call _scaleOpforCount;
    private _patrolSize = [6 + floor random 7, 2] call _scaleOpforCount;

    private _hvtCodename = selectRandom ["Viktor", "Dmitri", "Sergei", "Ivan", "Pavel", "Boris", "Volkov", "Kozlov"];
    private _hvtSlot = 2 + floor random ((count _bpos - 4) max 1);
    private _hvtPos = _bpos select _hvtSlot;
    if (count _hvtPos < 3) then { _hvtPos = [(_hvtPos select 0), (_hvtPos select 1), (_hvtPos param [2, 0])] };
    private _guardIndices = [];
    for "_i" from 0 to (count _bpos - 1) do { if (_i != _hvtSlot) then { _guardIndices pushBack _i } };

    private _hvtGroup = createGroup _sideEnemy;
    // Create HVT at a general building-interior position first, then snap to exact slot
    private _hvt = _hvtGroup createUnit [_hvtClass, getPosATL _targetBuilding, [], 0, "NONE"];
    // Disable movement and pathfinding BEFORE setPos to prevent AI from immediately walking away
    _hvt disableAI "PATH";
    _hvt disableAI "MOVE";
    _hvt allowDamage false;
    _hvt setPos _hvtPos;
    removeAllWeapons _hvt;
    removeAllItems _hvt;
    removeHeadgear _hvt;
    _hvt setIdentity ("FADE_hvt_" + _hvtCodename);
    [_hvt, _hvtPos] spawn {
        params ["_u", "_p"];
        sleep 0.2;
        _u setPos _p;
        removeAllWeapons _u;
        removeAllItems _u;
        removeHeadgear _u;
        private _berets = ["H_Beret_02", "H_Beret_Colonel", "H_Beret_Blk", "H_Beret_ocamo", "H_Beret_red", "H_Beret_gen_F"];
        { if (isClass (configFile >> "CfgWeapons" >> _x)) exitWith { _u addHeadgear _x } } forEach _berets;
        sleep 0.3;
        _u setPos _p;
        _u allowDamage true;
    };
    _hvt setUnitPos "MIDDLE";
    [_hvt, "SIT_LOW", "NONE", { !alive _this }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    private _hvtTypeName = getText (configFile >> "CfgVehicles" >> _hvtClass >> "displayName");
    if (_hvtTypeName == "") then { _hvtTypeName = _hvtClass };

    private _guardGroup = createGroup _sideEnemy;
    for "_i" from 0 to (_guardCount - 1) do {
        if (_i >= count _guardIndices) exitWith {};
        private _idx = _guardIndices select _i;
        private _p = _bpos select _idx;
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
        private _cls = _guardClasses select (_i mod (count _guardClasses));
        private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
        _u setUnitPos "MIDDLE";
        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    };
    [_guardGroup] call FAC_applyEnemyScenarioToGroup;

    private _buildingCenterPatrol = getPosATL _targetBuilding;
    if (count _buildingCenterPatrol < 3) then { _buildingCenterPatrol = [(_buildingCenterPatrol select 0), (_buildingCenterPatrol select 1), 0] };
    private _patrolBaseDist = 150;
    private _patrolDistVariance = 100;

    private _patrolGroups = [];
    for "_pg" from 0 to (_patrolGroupCount - 1) do {
        private _angle = random 360;
        private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
        if (_dist < 50) then { _dist = 50 };
        private _cx = (_buildingCenterPatrol select 0) + _dist * (cos _angle);
        private _cy = (_buildingCenterPatrol select 1) + _dist * (sin _angle);
        private _sp = [_cx, _cy, 0];
        _sp = [_sp, 0, 15, 3, 0, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
            for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
            private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
            [_grp] call FAC_applyEnemyScenarioToGroup;
            _grp setBehaviour "SAFE";
            for "_w" from 0 to 3 do {
                private _wpAngle = _w * 90;
                private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                if (_wpDist < 50) then { _wpDist = 50 };
                private _wpPos = [(_buildingCenterPatrol select 0) + _wpDist * (cos _wpAngle), (_buildingCenterPatrol select 1) + _wpDist * (sin _wpAngle), 0];
                _wpPos = [_wpPos, 0, 10, 2, 0, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
                if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                    _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
            };
            _patrolGroups pushBack _grp;
        };
    };

    // Additional guards garrisoned in nearby buildings (200 m radius), same as Hostage pattern
    private _hvtSurroundRadius = 200;
    private _hvtSurroundBuildings = (nearestObjects [getPosATL _targetBuilding, ["House", "Building"], _hvtSurroundRadius] select {
        !(_x isEqualTo _targetBuilding) && { count (_x buildingPos -1) >= 1 }
    }) select { random 1 < 0.4 };
    {
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then {} else {
            private _cnt = ([1 + floor random 3, 1] call _scaleOpforCount) min count _bldPos;
            private _indices = [];
            for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _surroundGrp = createGroup _sideEnemy;
            for "_i" from 0 to (_cnt - 1) do {
                private _p = _bldPos select (_indices select _i);
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                private _cls = selectRandom _enemyUnits;
                private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            };
            [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
            _patrolGroups pushBack _surroundGrp;
        };
    } forEach _hvtSurroundBuildings;

    private _hvtBarrel = objNull;
    private _buildingCenter = getPosATL _targetBuilding;
    if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
    private _barrelPos = [_buildingCenter, 8, 22, 2, 0, 0.3, 0, [], _buildingCenter] call BIS_fnc_findSafePos;
    if (_barrelPos isEqualType [] && { count _barrelPos >= 2 }) then {
        _barrelPos = [(_barrelPos select 0), (_barrelPos select 1), (_barrelPos param [2, 0])];
        _hvtBarrel = createVehicle ["MetalBarrel_burning_F", _barrelPos, [], 0, "NONE"];
        _hvtBarrel setPosATL _barrelPos;
    };

    [_player, _taskId, "Eliminate or capture the HVT. Return captive to base to complete.", "HVT", getPosATL _targetBuilding, "target"] call _fnc_createMissionTask;
    private _markerName = "FADE_hvt_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, getPosATL _targetBuilding];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText "HVT";

    private _grid = mapGridPosition (getPosATL _targetBuilding);
    private _brief = format ["HVT%1%1TARGET: Grid %2 (urban building)%1HVT: %3 -- %4%1%1Locate and eliminate the HVT, or capture and return them to base. HVT is unarmed and cannot move. Building is guarded; external patrols in the area.%1%1Complete when HVT is killed or delivered to base as captive.", toString [10], _grid, _hvtCodename, _hvtTypeName];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#FFCC00'>HVT: %2 -- %3</t><br/><br/><t color='#C0C0C0'>Eliminate or capture and return to base.</t>", _grid, _hvtCodename, _hvtTypeName]] call _showAssignedHint;
    [_player, "HVT"] call FADE_notifyOthersMissionStarted;

    private _allGroups = [_hvtGroup, _guardGroup] + _patrolGroups;
    [[_guardGroup] + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    private _hvtObjectivePos = getPosATL _targetBuilding;
    if (count _hvtObjectivePos < 3) then { _hvtObjectivePos = [(_hvtObjectivePos select 0), (_hvtObjectivePos select 1), 0] };
    [_taskId, _hvtObjectivePos, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hvt, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _hvtBarrel] spawn {
        params ["_taskId", "_hvt", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_hvtBarrel"];
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
                        _fleePos = [_fleePos, 0, 25, 3, 0, 0.5, 0, [], _fleePos] call BIS_fnc_findSafePos;
                        if (_fleePos isEqualType [] && { count _fleePos >= 2 }) then {
                            _hvt doMove _fleePos;
                        };
                    };
                };
            };
            _done
        };

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_allGroups, _markerName, _player, _hvtBarrel, _taskId] spawn {
            params ["_groups", "_markerName", "_player", "_hvtBarrel", "_taskId"];
            sleep 60;
            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
            if (!isNull _hvtBarrel) then { deleteVehicle _hvtBarrel };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// -----------------------------------------------------------------------------
// 5b. HOSTAGE -- Up to 3 civilian hostages in building(s); guards inside, patrols outside; return all alive to base
// -----------------------------------------------------------------------------
if (_missionType == "Hostage") exitWith {
    private _buildRadius = 450;
    private _minSlotsPerBuilding = 5;
    private _minSuitableBuildings = 2;
    private _baseDistForComplete = 100;
    private _minDistHostage = 1000;
    private _maxAttempts = 50;

    private _suitableBuildings = [];
    private _attempt = 0;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        _destPos = [_minDistHostage] call FADE_findMissionPosUrbanNearCenter;
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            _suitableBuildings = _buildings select { count (_x buildingPos -1) >= _minSlotsPerBuilding };
            if (count _suitableBuildings >= _minSuitableBuildings) exitWith {};
        };
    };
    if (count _suitableBuildings < _minSuitableBuildings) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No urban area with at least 2 suitable buildings (5+ positions each) near a civ zone. Check CIV_T_* triggers in towns and try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _hostageCount = 1 + floor random 3;
    private _civClasses = missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"]];
    if (_civClasses isEqualTo []) then { _civClasses = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };

    private _hostages = [];
    private _guardGroups = [];
    private _patrolGroups = [];
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
        private _bpos = _building buildingPos -1;
        private _startIdx = _nextSlotByBuilding select _buildingIdx;
        _nextSlotByBuilding set [_buildingIdx, _startIdx + _minSlotsPerBuilding];

        private _guardCount = [3 + floor random 4, 1] call _scaleOpforCount;
        private _midOffset = floor ((_minSlotsPerBuilding - 1) / 2);
        private _hostageIdx = _startIdx + _midOffset;
        private _hostagePos = _bpos select _hostageIdx;
        if (count _hostagePos < 3) then { _hostagePos = [(_hostagePos select 0), (_hostagePos select 1), (_hostagePos param [2, 0])] };

        private _civClass = selectRandom _civClasses;
        private _hostage = _hostageGroup createUnit [_civClass, _hostagePos, [], 0, "NONE"];
        removeAllWeapons _hostage;
        removeAllItems _hostage;
        removeHeadgear _hostage;
        removeGoggles _hostage;
        _hostage addGoggles "G_Blindfold_01_black_F";
        _hostage disableAI "PATH";
        _hostage setUnitPos "MIDDLE";
        _hostage switchMove "Acts_ExecutionVictim_Loop";
        _hostages pushBack _hostage;

        private _guardClasses = (_enemyUnits select [0, _guardCount min count _enemyUnits]);
        for "_g" from (count _guardClasses) to (_guardCount - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
        private _guardGroup = createGroup _sideEnemy;
        private _guardSlotIndices = [];
        for "_i" from 0 to (_minSlotsPerBuilding - 1) do {
            if (_startIdx + _i != _hostageIdx) then { _guardSlotIndices pushBack (_startIdx + _i) };
        };
        for "_i" from 0 to (_guardCount - 1) do {
            if (_i >= count _guardSlotIndices) exitWith {};
            private _idx = _guardSlotIndices select _i;
            private _p = _bpos select _idx;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
            private _cls = _guardClasses select (_i mod (count _guardClasses));
            private _u = _guardGroup createUnit [_cls, _p, [], 0, "NONE"];
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
        };
        [_guardGroup] call FAC_applyEnemyScenarioToGroup;
        _guardGroups pushBack _guardGroup;
    };

    if (count _hostages == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place hostages.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    // Additional guards in surrounding buildings (200 m radius), 40% chance per building, 1–3 units per building
    private _surroundRadius = 200;
    private _surroundBuildings = (nearestObjects [_destPos, ["House", "Building"], _surroundRadius] select { !(_x in _buildingsUsed) && { count (_x buildingPos -1) >= 1 } }) select { random 1 < 0.4 };
    {
        private _bld = _x;
        private _bpos = _bld buildingPos -1;
        if (_bpos isEqualTo []) then {} else {
            private _count = [1 + floor random 3, 1] call _scaleOpforCount;
            _count = _count min count _bpos;
            private _indices = [];
            for "_i" from 0 to (count _bpos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _guardClasses = (_enemyUnits select [0, _count min count _enemyUnits]);
            for "_k" from (count _guardClasses) to (_count - 1) do { _guardClasses pushBack (_enemyUnits select 0) };
            private _surroundGrp = createGroup _sideEnemy;
            for "_i" from 0 to (_count - 1) do {
                private _idx = _indices select _i;
                private _p = _bpos select _idx;
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                private _cls = _guardClasses select (_i mod (count _guardClasses));
                private _u = _surroundGrp createUnit [_cls, _p, [], 0, "NONE"];
                _u setUnitPos "MIDDLE";
                [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
            };
            [_surroundGrp] call FAC_applyEnemyScenarioToGroup;
            _guardGroups pushBack _surroundGrp;
        };
    } forEach _surroundBuildings;

    private _patrolBaseDist = 80;
    private _patrolDistVariance = 40;
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        for "_pg" from 0 to 1 do {
            private _angle = random 360;
            private _dist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
            if (_dist < 40) then { _dist = 40 };
            private _cx = (_buildingCenter select 0) + _dist * (cos _angle);
            private _cy = (_buildingCenter select 1) + _dist * (sin _angle);
            private _sp = [_cx, _cy, 0];
            _sp = [_sp, 0, 15, 3, 0, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _patrolSize = [2 + floor random 3, 1] call _scaleOpforCount;
                private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
                for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
                private _grp = [_sp, _sideEnemy, _patrolClasses] call BIS_fnc_spawnGroup;
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _wpAngle = _w * 90;
                    private _wpDist = _patrolBaseDist + (random (2 * _patrolDistVariance) - _patrolDistVariance);
                    if (_wpDist < 40) then { _wpDist = 40 };
                    private _wpPos = [(_buildingCenter select 0) + _wpDist * (cos _wpAngle), (_buildingCenter select 1) + _wpDist * (sin _wpAngle), 0];
                    _wpPos = [_wpPos, 0, 10, 2, 0, 0.4, 0, [], _wpPos] call BIS_fnc_findSafePos;
                    if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                        _wpPos = [(_wpPos select 0), (_wpPos select 1), (_wpPos param [2, 0])];
                        private _wp = _grp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                        if (_w == 3) then { _wp setWaypointType "CYCLE" };
                    };
                };
                _patrolGroups pushBack _grp;
            };
        };
    } forEach _buildingsUsed;

    private _missionCenter = getPosATL (_buildingsUsed select 0);
    if (count _missionCenter < 3) then { _missionCenter = [(_missionCenter select 0), (_missionCenter select 1), 0] };

    [_player, _taskId, "Rescue the hostages. Return all alive hostages to base (within 100 m). Mission fails if more than half die.", "Hostage", _missionCenter, "run"] call _fnc_createMissionTask;
    private _markerName = "FADE_hostage_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _missionCenter];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorCIV";
    _marker setMarkerText "Hostage";

    private _grid = mapGridPosition _missionCenter;
    private _brief = format ["HOSTAGE%1%1TARGET: Grid %2 (urban building(s))%1HOSTAGES: %3 civilian(s)%1%1Rescue the hostages from the building(s). Each is guarded; patrols operate outside. Return all alive hostages to base (within 100 m). Mission fails if more than half the hostages die.%1%1Complete when every surviving hostage is at base.", toString [10], _grid, count _hostages];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#FFCC00'>%2 hostage(s)</t><br/><br/><t color='#C0C0C0'>Rescue and return all alive to base (within 100 m).</t>", _grid, count _hostages]] call _showAssignedHint;
    [_player, "Hostage"] call FADE_notifyOthersMissionStarted;

    private _initialHostageCount = count _hostages;
    private _allGroups = [_hostageGroup] + _guardGroups + _patrolGroups;
    [_guardGroups + _patrolGroups, _basePos] call FADE_registerEnemyRetreat;

    [_taskId, _missionCenter, _basePos, _enemyUnits, _allGroups, -1] call FADE_counterAttackStart;

    [_taskId, _hostages, _basePos, _baseDistForComplete, _markerName, _player, _allGroups, _initialHostageCount] spawn {
        params ["_taskId", "_hostages", "_basePos", "_baseDistForComplete", "_markerName", "_player", "_allGroups", "_initialHostageCount"];
        private _done = false;

        waitUntil {
            sleep 0.5;
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) then { _done = true };
            private _alive = _hostages select { alive _x };
            private _aliveCount = count _alive;
            if (!_done && _aliveCount < (ceil (_initialHostageCount / 2))) then {
                [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                ["<t size='1.2' color='#FF6666'>MISSION FAILED</t><br/><br/><t color='#E0E0E0'>Too many hostages lost.</t>"] remoteExec ["FADE_showMissionHint", _player];
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

        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        [_allGroups, _markerName, _player, _hostages, _taskId] spawn {
            params ["_groups", "_markerName", "_player", "_hostages", "_taskId"];
            sleep 60;
            { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _hostages;
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// -----------------------------------------------------------------------------
// 6. CLEAR AREA -- Occupied town (civ zone) or enemy camp; destroy 80% of enemies
// -----------------------------------------------------------------------------
if (_missionType == "ClearArea") exitWith {
    // Use same resolved list as rest of Missions.sqf (FADE_resolveScenarioEnemyUnits — scenario faction first)
    private _enemyUnitsCA = +_enemyUnits;
    _enemyUnitsCA = [_enemyUnitsCA] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsCA == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Use only classnames from our list (no createUnit with side default that could spawn CSAT)
    private _baseClassCA = _enemyUnitsCA select 0;
    private _useTown = random 1 > 0.5;
    private _center = _destPos;
    private _campObjects = [];
    // Must exist before camp branch: stationary spawns push into _allGroups (was after town/camp block - undefined variable)
    private _allGroups = [];
    if (_useTown) then {
        private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
        if (count _civZones > 0) then {
            private _zoneName = selectRandom _civZones;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then { _center = getPosATL _trig };
        };
    } else {
        _center = [_destPos, 0, 400, 100, 0, 0.3, 0, [], _destPos] call BIS_fnc_findSafePos;
        if (count _center < 2) then { _center = _destPos };
        if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
        // Multiple camp compositions to choose from randomly for variety
        private _campVariants = [
            // Variant A: patrol forward base
            [
                ["Land_TentA_F", 12, 0], ["Land_TentDome_F", 15, 180], ["Land_CampingTable_F", 8, 90],
                ["Campfire_burning_F", 6, 270], ["Box_NATO_Ammo_F", 18, 45], ["Box_NATO_Support_F", 18, 315]
            ],
            // Variant B: dug-in position with sandbags
            [
                ["Land_BagFence_Round_F", 5, 0], ["Land_BagFence_Round_F", 5, 90], ["Land_BagFence_Round_F", 5, 180],
                ["Land_TentA_F", 16, 225], ["Campfire_burning_F", 4, 315], ["Box_NATO_Ammo_F", 20, 60]
            ],
            // Variant C: roadside checkpoint
            [
                ["Land_Barrier_01_wide_F", 8, 0], ["Land_Barrier_01_wide_F", 8, 180],
                ["Land_CampingTable_F", 6, 90], ["Campfire_burning_F", 5, 270],
                ["Land_TentDome_F", 14, 45], ["Box_NATO_Ammo_F", 16, 135]
            ],
            // Variant D: logistics camp
            [
                ["Land_TentA_F", 10, 30], ["Land_TentA_F", 10, 150], ["Land_TentDome_F", 14, 270],
                ["Land_CampingTable_F", 7, 60], ["Land_CampingChair_V2_F", 8, 100],
                ["Box_NATO_Ammo_F", 20, 0], ["Box_NATO_Support_F", 20, 180], ["Campfire_burning_F", 5, 230]
            ],
            // Variant E: minimal hide
            [
                ["Land_TentDome_F", 8, 0], ["Campfire_burning_F", 5, 180],
                ["Box_NATO_Ammo_F", 12, 90], ["Land_CampingTable_F", 10, 270]
            ]
        ];
        private _campComp = selectRandom _campVariants;
        {
            _x params ["_cls", "_dist", "_angle"];
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [_p, 0, 2, 0, 0, 0.3, 0, [], _p] call BIS_fnc_findSafePos;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _obj = createVehicle [_cls, _p, [], 0, "NONE"];
                _obj setPosATL _p;
                _campObjects pushBack _obj;
            };
        } forEach _campComp;

        // Stationary enemies at the camp itself (ambient combat anims like HVT/Hostage guards)
        private _stationaryCount = [3 + floor random 5, 1] call _scaleOpforCount;
        private _campCenterArea = [_center, 0, 20, 2, 0, 0.4, 0, [], _center] call BIS_fnc_findSafePos;
        if (count _campCenterArea < 2) then { _campCenterArea = _center };
        for "_si" from 0 to (_stationaryCount - 1) do {
            private _angle = (_si / _stationaryCount) * 360 + (random 30 - 15);
            private _dist = 3 + random 12;
            private _p = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
            _p = [_p, 0, 2, 0, 0, 0.3, 0, [], _p] call BIS_fnc_findSafePos;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _p = [(_p select 0), (_p select 1), (_p param [2, 0])];
                private _cls = selectRandom _enemyUnitsCA;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _p;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                } else { deleteGroup _grp };
            };
        };
    };
    if (count _center >= 2 && { count _center < 3 }) then { _center = [(_center select 0), (_center select 1), 0] };
    private _areaRadius = if (_useTown) then { 280 } else { 120 };
    private _buildings = nearestObjects [_center, ["House", "Building"], _areaRadius];
    private _usedPositions = [];
    private _maxUnitsPerBuilding = 2;
    private _maxGarrisonTotal = [35, 8] call _scaleOpforCount;
    {
        private _bps = _x buildingPos -1;
        private _addedThisBuilding = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
            if (_addedThisBuilding >= _maxUnitsPerBuilding) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _cls = selectRandom _enemyUnitsCA;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                    _usedPositions pushBack _pos;
                    _addedThisBuilding = _addedThisBuilding + 1;
                };
            };
        };
        if (count _usedPositions >= _maxGarrisonTotal) exitWith {};
    } forEach _buildings;
    private _numPatrols = [2 + floor random 3, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 30 + random (_areaRadius - 30);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [_sp, 0, 15, 3, 0, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 5, 1] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsCA) then { _enemyUnitsCA select _k } else { _baseClassCA };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 3 do {
                    private _a = _w * 90 + (random 30);
                    private _d = 40 + random (_areaRadius - 40);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 3) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };
    private _areaVehicles = [];
    private _enemyVehList = missionNamespace getVariable ["FADE_enemyVehicles", []];
    if (_enemyVehList isEqualTo []) then {
        private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
        _enemyVehList = [_ef] call FADE_getEnemyVehiclesForFaction;
    };
    private _landVehClasses = _enemyVehList select { !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } };
    if (count _landVehClasses > 0) then {
        private _roads = _center nearRoads _areaRadius;
        if (count _roads > 0) then {
            private _numVeh = [1 + floor random 3, 1] call _scaleOpforCount;
            _numVeh = _numVeh min count _roads;
            private _roadShuf = _roads call BIS_fnc_arrayShuffle;
            for "_nv" from 0 to (_numVeh - 1) do {
                private _roadObj = _roadShuf select _nv;
                private _roadPos = getPosATL _roadObj;
                if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
                private _vClass = selectRandom _landVehClasses;
                private _veh = createVehicle [_vClass, _roadPos, [], 0, "NONE"];
                if (!isNull _veh) then {
                    _veh setPosATL _roadPos;
                    _areaVehicles pushBack _veh;
                    private _vehGrp = createGroup _sideEnemy;
                    private _driver = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                    if (!isNull _driver) then { _driver moveInDriver _veh };
                    if (_veh emptyPositions "gunner" > 0) then {
                        private _g = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _g) then { _g moveInGunner _veh };
                    };
                    if (_veh emptyPositions "commander" > 0) then {
                        private _c = _vehGrp createUnit [selectRandom _enemyUnitsCA, _roadPos, [], 0, "NONE"];
                        if (!isNull _c) then { _c moveInCommander _veh };
                    };
                    [_vehGrp] call FAC_applyEnemyScenarioToGroup;
                    _vehGrp setBehaviour "SAFE";
                    _vehGrp setSpeedMode "LIMITED";
                    private _wpAngle = random 360;
                    private _wpDist = 30 + random 170;
                    private _wpPos = [(_center select 0) + _wpDist * (cos _wpAngle), (_center select 1) + _wpDist * (sin _wpAngle), 0];
                    _wpPos = [_wpPos, 0, 20, 10, 0, 0.3, 0, [], _wpPos] call BIS_fnc_findSafePos;
                    if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
                        if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
                        private _wp = _vehGrp addWaypoint [_wpPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "LIMITED";
                    };
                    _allGroups pushBack _vehGrp;
                };
            };
        };
    };
    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    if (_initialCount == 0) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _areaVehicles;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies in area.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _markerName = "FADE_clear_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _marker = createMarker [_markerName, _center];
        _marker setMarkerType "mil_objective";
        _marker setMarkerColor _markerEnemy;
        _marker setMarkerText (if (_useTown) then { "Clear Town" } else { "Clear Camp" });
        private _grid = mapGridPosition _center;
        [_player, _taskId, "Destroy at least 80% of enemy forces in the area.", "Clear Area", _center, "attack"] call _fnc_createMissionTask;
        private _brief = format ["CLEAR AREA%1%1TARGET: Grid %2 (%3)%1%1Neutralize at least 80% of enemy forces.", toString [10], _grid, if (_useTown) then { "occupied town" } else { "enemy camp" }];
        _player setVariable ["FADE_myMissionBrief", _brief, true];
        [format ["<t color='#B0B0B0'>Grid: %1 -- %2</t><br/><br/><t color='#C0C0C0'>Destroy 80%%+ of enemy forces.</t>", _grid, if (_useTown) then { "town" } else { "camp" }]] call _showAssignedHint;
        [_player, "Clear Area"] call FADE_notifyOthersMissionStarted;
        private _caDetect = (_areaRadius + 180) max 320;
        [_taskId, _center, _basePos, _enemyUnitsCA, _allGroups, _caDetect] call FADE_counterAttackStart;
        private _clearTimeout = 900;
        [_taskId, _allGroups, _initialCount, _markerName, _player, _campObjects, _areaVehicles, _clearTimeout] spawn {
            params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_campObjects", "_areaVehicles", "_timeout"];
            private _start = time;
            waitUntil {
                sleep 0.5;
                if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"]) exitWith { true };
                if (time - _start > _timeout) exitWith { true };
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                if (_alive <= _initialCount * 0.2) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    true
                } else { false };
            };
            if (!((_taskId call BIS_fnc_taskState) in ["SUCCEEDED","CANCELED","FAILED"])) then {
                private _alive = 0;
                { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
                if (_alive <= _initialCount * 0.2) then { [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState } else { [_taskId, "CANCELED"] call BIS_fnc_taskSetState };
            };
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            [_allGroups, _campObjects, _areaVehicles, _markerName, _player, _taskId] spawn {
                params ["_groups", "_campObjects", "_areaVehicles", "_markerName", "_player", "_taskId"];
                sleep 60;
                { if (!isNull _x) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } } forEach _groups;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _campObjects;
                { if (!isNull _x) then { deleteVehicle _x } } forEach _areaVehicles;
                [_markerName] call FADE_deleteMarkerSafe;
                if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            };
        };
    };
};

// -----------------------------------------------------------------------------
// 6b. SEARCH & DESTROY -- Three buildings in civ area; garrison only those + patrols
// -----------------------------------------------------------------------------
if (_missionType == "SearchDestroy") exitWith {
    private _enemyUnitsSd = +_enemyUnits;
    _enemyUnitsSd = [_enemyUnitsSd] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsSd == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No enemy units configured.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _baseClassSd = _enemyUnitsSd select 0;
    // Same civ-zone + near-center pattern as Hostage: random urban pos can land in empty ground — loop until
    // three enterable buildings (2+ buildingPos slots) exist within radius, trying random zones then every CIV_T_*.
    private _minDistUrban = 1000;
    private _areaRadius = 300;
    private _trySdPickBuildings = {
        params ["_pos", "_radius"];
        if (count _pos < 2) exitWith { [[], []] };
        private _c = +_pos;
        if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
        private _buildings = nearestObjects [_c, ["House", "Building"], _radius];
        private _cands = _buildings call BIS_fnc_arrayShuffle;
        private _pickedTrial = [];
        {
            if (count _pickedTrial >= 3) exitWith {};
            private _bps = _x buildingPos -1;
            if (count _bps >= 2) then { _pickedTrial pushBack _x };
        } forEach _cands;
        if (count _pickedTrial >= 3) then {
            [_c, _pickedTrial select [0, 3]]
        } else {
            [[], []]
        };
    };
    private _center = [];
    private _picked = [];
    private _maxAttempts = 50;
    private _attempt = 0;
    while { _attempt < _maxAttempts } do {
        _attempt = _attempt + 1;
        private _tryPos = [_minDistUrban] call FADE_findMissionPosUrbanNearCenter;
        private _res = [_tryPos, _areaRadius] call _trySdPickBuildings;
        _res params ["_cPos", "_bList"];
        if (count _bList >= 3) exitWith {
            _center = _cPos;
            _picked = _bList;
        };
    };
    if (count _picked < 3) then {
        private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zones = _zones call BIS_fnc_arrayShuffle;
        {
            if (count _picked >= 3) exitWith {};
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if ((_zc distance _basePos) >= _minDistUrban) then {
                    private _tryPos = [_zc, 50, 400, 5, 0.5, 0.5, 0, [], _zc] call BIS_fnc_findSafePos;
                    private _res2 = [_tryPos, _areaRadius] call _trySdPickBuildings;
                    _res2 params ["_cPos2", "_bList2"];
                    if (count _bList2 >= 3) then {
                        _center = _cPos2;
                        _picked = _bList2;
                    };
                };
            };
        } forEach _zones;
    };

    if (count _picked < 3) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No town with three enterable buildings near a civ zone (CIV_T_*). Add triggers in built-up areas or try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    private _allGroups = [];
    {
        private _building = _x;
        private _bps = _building buildingPos -1;
        private _addedThis = 0;
        for "_i" from 0 to (count _bps - 1) do {
            if (_addedThis >= 2) exitWith {};
            private _pos = _bps select _i;
            if (count _pos >= 2) then {
                if (count _pos < 3) then { _pos = [(_pos select 0), (_pos select 1), 0] };
                private _cls = selectRandom _enemyUnitsSd;
                private _grp = createGroup _sideEnemy;
                private _u = _grp createUnit [_cls, _pos, [], 0, "NONE"];
                if (!isNull _u) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    _u setPos _pos;
                    _u setUnitPos "MIDDLE";
                    [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
                    _allGroups pushBack _grp;
                    _addedThis = _addedThis + 1;
                } else { deleteGroup _grp };
            };
        };
    } forEach _picked;

    // GM ammo pile props (one per garrisoned building, one building position each) — Global Mobilization CfgVehicles; skipped if not loaded
    private _sdAmmoClasses = [
        "gm_ammobox_pile_small_03_empty",
        "gm_ammobox_pile_small_02_empty",
        "gm_ammobox_pile_large_02_empty"
    ];
    private _sdAmmoClassesOk = _sdAmmoClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    private _sdAmmoObjs = [];
    if (count _sdAmmoClassesOk > 0) then {
        {
            private _building = _x;
            private _bps = _building buildingPos -1;
            if (count _bps > 0) then {
                private _ammoBp = if (count _bps > 2) then { _bps select 2 } else { selectRandom _bps };
                if (count _ammoBp >= 2) then {
                    if (count _ammoBp < 3) then { _ammoBp = [(_ammoBp select 0), (_ammoBp select 1), 0] };
                    private _cls = selectRandom _sdAmmoClassesOk;
                    private _obj = createVehicle [_cls, _ammoBp, [], 0, "NONE"];
                    if (!isNull _obj) then {
                        _obj setPosATL _ammoBp;
                        _obj setDir ((getDir _building) + random 360);
                        _sdAmmoObjs pushBack _obj;
                    };
                };
            };
        } forEach _picked;
    };

    private _numPatrols = [2, 1] call _scaleOpforCount;
    for "_g" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 40 + random (_areaRadius - 50);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [_sp, 0, 15, 3, 0, 0.4, 0, [], _sp] call BIS_fnc_findSafePos;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [3 + floor random 3, 2] call _scaleOpforCount;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = if (_k < count _enemyUnitsSd) then { _enemyUnitsSd select _k } else { _baseClassSd };
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPos _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 2 do {
                    private _a = _w * 120 + (random 40);
                    private _d = 50 + random(_areaRadius - 50);
                    private _wpPos = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    private _wp = _grp addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "LIMITED";
                    if (_w == 2) then { _wp setWaypointType "CYCLE" };
                };
                _allGroups pushBack _grp;
            } else { deleteGroup _grp };
        };
    };

    [_allGroups, _basePos] call FADE_registerEnemyRetreat;
    private _initialCount = 0;
    { _initialCount = _initialCount + count units _x } forEach _allGroups;
    if (_initialCount == 0) exitWith {
        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdAmmoObjs;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn enemies.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, [_allGroups, _sdAmmoObjs]];
    missionNamespace setVariable ["FADE_sdAborted_" + _taskId, false];

    private _markerName = "FADE_sd_" + _taskId;
    missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, _markerName];
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _marker = createMarker [_markerName, _center];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor _markerEnemy;
    _marker setMarkerText "S&D: 3 buildings";

    private _grid = mapGridPosition _center;
    [_player, _taskId, format ["Clear %1 marked buildings and all patrols in the area.", count _picked], "Search & Destroy", _center, "attack"] call _fnc_createMissionTask;
    private _brief = format ["SEARCH & DESTROY%1%1%2 buildings in town grid %3 — garrison only inside those structures; patrols outside.%1%1Destroy all hostiles.", toString [10], count _picked, _grid];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Grid: %1</t><br/><br/><t color='#C0C0C0'>Clear %2 buildings + patrols.</t>", _grid, count _picked]] call _showAssignedHint;
    [_player, "Search & Destroy"] call FADE_notifyOthersMissionStarted;

    private _sdDetect = (_areaRadius + 120) max 280;
    [_taskId, _center, _basePos, _enemyUnitsSd, _allGroups, _sdDetect] call FADE_counterAttackStart;

    private _sdTimeout = 900;
    [_taskId, _allGroups, _initialCount, _markerName, _player, _sdTimeout, _sdAmmoObjs] spawn {
        params ["_taskId", "_allGroups", "_initialCount", "_markerName", "_player", "_timeout", "_sdAmmoObjs"];
        private _start = time;
        waitUntil {
            sleep 0.5;
            if (missionNamespace getVariable ["FADE_sdAborted_" + _taskId, false]) exitWith { true };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith { true };
            if (time - _start > _timeout) exitWith { true };
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _allGroups;
            if (_alive == 0) exitWith {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                true
            };
            false
        };
        if ((time - _start > _timeout) && { (_taskId call BIS_fnc_taskState) == "ASSIGNED" }) then {
            [_taskId, "CANCELED"] call BIS_fnc_taskSetState;
        };
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        missionNamespace setVariable ["FADE_searchDestroyEntities_" + _taskId, nil];
        missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, nil];
        missionNamespace setVariable ["FADE_sdAborted_" + _taskId, nil];
        sleep 60;
        { if (!isNull _x) then { { deleteVehicle _x } forEach units _x; deleteGroup _x } } forEach _allGroups;
        { if (!isNull _x) then { deleteVehicle _x } } forEach _sdAmmoObjs;
    };
};

// -----------------------------------------------------------------------------
// 7. INTERCEPT CONVOY -- Convoy 3-6 vehicles (road start → end, 2km+); destroy 100% before arrival
// -----------------------------------------------------------------------------
if (_missionType == "InterceptConvoy") exitWith {
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
    private _roadPoints = [];
    for "_i" from 1 to 25 do {
        private _obj = missionNamespace getVariable [format ["ROAD_SP_%1", _i], objNull];
        if (!isNull _obj) then { _roadPoints pushBack _obj };
    };
    if (count _roadPoints < 2) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Need at least 2 ROAD_SP_* points in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _startIdx = floor random count _roadPoints;
    private _endIdx = _startIdx;
    private _attempts = 0;
    private _bestDist = 0;
    private _bestStart = _startIdx;
    private _bestEnd = _endIdx;
    while { _attempts < 30 } do {
        _endIdx = floor random count _roadPoints;
        if (_endIdx != _startIdx) then {
            private _sp = getPosATL (_roadPoints select _startIdx);
            private _ep = getPosATL (_roadPoints select _endIdx);
            private _d = _sp distance _ep;
            if (_d > _bestDist) then { _bestDist = _d; _bestStart = _startIdx; _bestEnd = _endIdx };
            if (_d >= 2000) exitWith {};
        };
        _attempts = _attempts + 1;
    };
    if (_bestDist < 2000 && { count _roadPoints >= 2 }) then {
        private _allPairs = [];
        { for "_j" from (_forEachIndex + 1) to (count _roadPoints - 1) do {
            private _d = (getPosATL _x) distance (getPosATL (_roadPoints select _j));
            _allPairs pushBack [_d, _forEachIndex, _j];
            if (_d > _bestDist) then { _bestDist = _d };
        } } forEach _roadPoints;
        private _minDist = (_bestDist * 0.7) max 500;
        private _candidates = _allPairs select { (_x select 0) >= _minDist };
        if (count _candidates == 0) then { _candidates = _allPairs };
        private _chosen = selectRandom _candidates;
        _bestStart = _chosen select 1;
        _bestEnd = _chosen select 2;
    };
    _startIdx = _bestStart;
    _endIdx = _bestEnd;
    private _startPos = getPosATL (_roadPoints select _startIdx);
    private _endPos = getPosATL (_roadPoints select _endIdx);
    if (count _startPos < 3) then { _startPos = [(_startPos select 0), (_startPos select 1), 0] };
    if (count _endPos < 3) then { _endPos = [(_endPos select 0), (_endPos select 1), 0] };
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
    private _convoyGroup = createGroup _sideEnemy;
    private _convoyVehiclesSpawned = [];
    private _convoySpawnEntries = [];
    private _cargoGroups = [];
    private _convoyWp = [];
    private _dir = [_startPos, _endPos] call BIS_fnc_dirTo;
    private _findConvoySafeSpawn = {
        params ["_desiredPos", ["_minVehGap", 12], ["_buildingGap", 10]];
        if (count _desiredPos < 3) then { _desiredPos = [(_desiredPos select 0), (_desiredPos select 1), 0] };
        private _fallback = _desiredPos;
        private _best = [];
        private _done = false;
        for "_try" from 0 to 9 do {
            if (_done) then { continue };
            private _candidate = [_desiredPos, 0, 16, 6, 0, 0.3, 0, [], _fallback] call BIS_fnc_findSafePos;
            if (count _candidate < 2) then { _candidate = _fallback };
            if (count _candidate < 3) then { _candidate = [(_candidate select 0), (_candidate select 1), 0] };
            private _tooCloseVeh = false;
            {
                if (!isNull _x && { alive _x } && { (_x distance2D _candidate) < _minVehGap }) exitWith { _tooCloseVeh = true };
            } forEach _convoyVehiclesSpawned;
            if (_tooCloseVeh) then { continue };
            private _nearBuildings = nearestTerrainObjects [_candidate, ["HOUSE","BUILDING","WALL","FENCE"], _buildingGap, false, true];
            if (count _nearBuildings > 0) then { continue };
            _best = _candidate;
            _done = true;
        };
        if (count _best < 2) then { _best = _fallback };
        if (count _best < 3) then { _best = [(_best select 0), (_best select 1), 0] };
        _best
    };
    private _spawnConvoyVehicle = {
        params ["_vClass", "_spawnPos"];
        if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };
        private _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
        if (isNull _veh) exitWith { [objNull, grpNull] };
        _veh setPosATL _spawnPos;
        _veh setDir _dir;
        // Small forward nudge helps newly spawned convoy vehicles break static friction/get unstuck.
        private _nudge = 2;
        _veh setVelocity [ (sin _dir) * _nudge, (cos _dir) * _nudge, 0 ];
        private _cargoGrp = grpNull;
        if (count _enemyUnitsConv > 0) then {
            private _driver = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
            if (!isNull _driver) then { _driver moveInDriver _veh };
            if (_veh emptyPositions "gunner" > 0) then {
                private _g = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
                if (!isNull _g) then { _g moveInGunner _veh };
            };
            if (_veh emptyPositions "commander" > 0) then {
                private _c = _convoyGroup createUnit [selectRandom _enemyUnitsConv, _spawnPos, [], 0, "NONE"];
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
        [_veh, _cargoGrp]
    };

    // Spawn lead vehicle first, then stagger followers to reduce spawn-gridlock.
    if (count _vehicleClasses > 0) then {
        private _leadSpawn = [_startPos, 14, 12] call _findConvoySafeSpawn;
        private _leadResult = [(_vehicleClasses select 0), _leadSpawn] call _spawnConvoyVehicle;
        private _leadVeh = _leadResult select 0;
        if (!isNull _leadVeh) then {
            _convoyVehiclesSpawned pushBack _leadVeh;
            private _cg = _leadResult select 1;
            if (!isNull _cg) then { _cargoGroups pushBack _cg };
            _convoySpawnEntries pushBack [_leadVeh, (_vehicleClasses select 0), _leadSpawn, false, _cg];
            // Give move orders immediately so lead starts driving while followers spawn.
            _convoyGroup setFormation "COLUMN";
            _convoyGroup setBehaviour "SAFE";
            _convoyGroup setSpeedMode "NORMAL";
            _convoyWp = _convoyGroup addWaypoint [_endPos, 20];
            _convoyWp setWaypointType "MOVE";
            _convoyWp setWaypointSpeed "NORMAL";
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
            private _res = [_vClass, _safeBehind] call _spawnConvoyVehicle;
            private _veh = _res select 0;
            if (!isNull _veh) then {
                _convoyVehiclesSpawned pushBack _veh;
                private _cg2 = _res select 1;
                if (!isNull _cg2) then { _cargoGroups pushBack _cg2 };
                _convoySpawnEntries pushBack [_veh, _vClass, _safeBehind, false, _cg2];
            };
        };
    };
    // One-time recovery: respawn exploded or non-moving convoy vehicles once.
    sleep 8;
    for "_i" from 0 to (count _convoySpawnEntries - 1) do {
        private _entry = _convoySpawnEntries select _i;
        _entry params ["_veh", "_vClass", "_spawnPos", "_retried", "_cargoGrp"];
        private _needsRespawn = isNull _veh || { !alive _veh } || { !canMove _veh } || { speed _veh < 1 };
        if (_needsRespawn && { !_retried }) then {
            if (!isNull _cargoGrp) then {
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _cargoGrp;
                deleteGroup _cargoGrp;
                _cargoGroups = _cargoGroups - [_cargoGrp];
            };
            if (!isNull _veh) then { deleteVehicle _veh };
            private _retryPos = [_spawnPos, 12, 10] call _findConvoySafeSpawn;
            private _retryRes = [_vClass, _retryPos] call _spawnConvoyVehicle;
            private _retryVeh = _retryRes select 0;
            private _retryCargo = _retryRes select 1;
            if (!isNull _retryCargo) then { _cargoGroups pushBack _retryCargo };
            if (!isNull _retryVeh) then {
                _entry = [_retryVeh, _vClass, _retryPos, true, _retryCargo];
                _convoySpawnEntries set [_i, _entry];
            };
        };
    };
    _convoyVehiclesSpawned = (_convoySpawnEntries apply { _x select 0 }) select { !isNull _x && { alive _x } };
    // Cleanup: delete any convoy infantry that failed to board (prevents stragglers at spawn).
    {
        if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
    } forEach units _convoyGroup;
    {
        {
            if (!isNull _x && { alive _x } && { vehicle _x == _x }) then { deleteVehicle _x };
        } forEach units _x;
    } forEach _cargoGroups;
    [_convoyGroup] call FAC_applyEnemyScenarioToGroup;
    { [_x] call FAC_applyEnemyScenarioToGroup } forEach _cargoGroups;
    if (count _convoyVehiclesSpawned == 0) exitWith {
        deleteGroup _convoyGroup;
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGroups;
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn convoy vehicles.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    _convoyGroup setVariable ["FADE_convoyTaskId", _taskId, true];
    _convoyGroup setVariable ["FADE_convoyVehiclesList", _convoyVehiclesSpawned, true];
    _convoyGroup setVariable ["FADE_convoyCargoGroups", _cargoGroups, true];
    if (count _convoyWp == 0) then {
        _convoyGroup setFormation "COLUMN";
        _convoyGroup setBehaviour "SAFE";
        _convoyGroup setSpeedMode "NORMAL";
        _convoyWp = _convoyGroup addWaypoint [_endPos, 20];
        _convoyWp setWaypointType "MOVE";
        _convoyWp setWaypointSpeed "NORMAL";
    };
    {
        if (!isNull _x) then { _x setConvoySeparation 20 };
    } forEach _convoyVehiclesSpawned;
    _convoyWp setWaypointStatements ["true", "
        private _g = group this;
        private _task = _g getVariable ['FADE_convoyTaskId', ''];
        if (_task != '' && { (_task call BIS_fnc_taskState) != 'SUCCEEDED' }) then { [_task, 'FAILED'] call BIS_fnc_taskSetState };
        private _vList = _g getVariable ['FADE_convoyVehiclesList', []];
        { if (!isNull _x) then { deleteVehicle _x } } forEach _vList;
        private _cargoGrps = _g getVariable ['FADE_convoyCargoGroups', []];
        { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGrps;
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _g;
        deleteGroup _g;
    "];
    [[_convoyGroup] + _cargoGroups, _basePos] call FADE_registerEnemyRetreat;
    private _markerNameStart = "FADE_convoy_start_" + _taskId;
    private _markerNameEnd = "FADE_convoy_end_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerNameStart, true];
    _player setVariable ["FADE_myMissionMarkerEnd", _markerNameEnd, true];
    private _markerStart = createMarker [_markerNameStart, _startPos];
    _markerStart setMarkerType "mil_arrow";
    _markerStart setMarkerColor _markerEnemy;
    _markerStart setMarkerText "Convoy Start";
    private _markerEnd = createMarker [_markerNameEnd, _endPos];
    _markerEnd setMarkerType "mil_end";
    _markerEnd setMarkerColor _markerEnemy;
    _markerEnd setMarkerText "Convoy End";
    [_player, _taskId, "Stop the convoy: destroy or immobilise at least 60% of vehicles before they reach the end zone.", "Intercept Convoy", _endPos, "destroy"] call _fnc_createMissionTask;
    private _gridStart = mapGridPosition _startPos;
    private _gridEnd = mapGridPosition _endPos;
    private _brief = format ["INTERCEPT CONVOY%1%1START: Grid %2%1END: Grid %3%1%1Stop the convoy: at least 60%% of vehicles destroyed or immobilised before they arrive.", toString [10], _gridStart, _gridEnd];
    _player setVariable ["FADE_myMissionBrief", _brief, true];
    [format ["<t color='#B0B0B0'>Start: %1 -> End: %2</t><br/><br/><t color='#C0C0C0'>Stop the convoy: at least 60%% of vehicles destroyed or immobilised.</t>", _gridStart, _gridEnd]] call _showAssignedHint;
    [_player, "Intercept Convoy"] call FADE_notifyOthersMissionStarted;
    private _friendlyObserverClass = _friendlyUnits select 0;
    [_taskId, _convoyVehiclesSpawned, _convoyGroup, _cargoGroups, _markerNameStart, _markerNameEnd, _player, _endPos, _startPos, _friendlyObserverClass, _sideFriendly] spawn {
        params ["_taskId", "_convoyVehiclesSpawned", "_convoyGroup", "_cargoGroups", "_markerNameStart", "_markerNameEnd", "_player", "_endPos", "_startPos", "_friendlyObserverClass", "_sideFriendly"];
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
        [_convoyGroup, _convoyVehiclesSpawned, _cargoGroups, _markerNameStart, _markerNameEnd, _player, _taskId] spawn {
            params ["_convoyGroup", "_convoyVehiclesSpawned", "_cargoGroups", "_markerNameStart", "_markerNameEnd", "_player", "_taskId"];
            sleep 60;
            if (!isNull _convoyGroup) then { { if (!isNull _x) then { deleteVehicle _x } } forEach units _convoyGroup; deleteGroup _convoyGroup };
            { { if (!isNull _x) then { deleteVehicle _x } } forEach units _x; deleteGroup _x } forEach _cargoGroups;
            { if (!isNull _x) then { deleteVehicle _x } } forEach _convoyVehiclesSpawned;
            [_markerNameStart] call FADE_deleteMarkerSafe;
            [_markerNameEnd] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

// Mine Clearing, Find and Clear IEDs, Medical/MASCAS - see separate blocks below
if (_missionType == "MineClearing") exitWith {
    private _numMines = 5 + floor random 6;
    private _mineClass = "APERSBoundingMine";
    if (!isClass (configFile >> "CfgVehicles" >> _mineClass)) then { _mineClass = "APERSMine" };
    private _mines = [];
    for "_i" from 0 to (_numMines - 1) do {
        private _pos = [_destPos, random 200, random 360] call BIS_fnc_relPos;
        _pos = [_pos, 0, 15, 2, 0, 0.35, 0, [], _pos] call BIS_fnc_findSafePos;
        if (_pos isEqualType [] && { count _pos >= 2 }) then {
            if (count _pos < 3) then { _pos set [2, 0] };
            private _m = createMine [_mineClass, _pos, [], 0];
            _mines pushBack _m;
        };
    };
    if (_mines isEqualTo []) then {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not place mines.</t>"] remoteExec ["FADE_showMissionHint", _player];
    } else {
        [_player, _taskId, "Clear all mines in the area.", "Mine Clearing", _destPos, "destroy"] call _fnc_createMissionTask;
        private _markerName = "FADE_mines_" + _taskId;
        _player setVariable ["FADE_myMissionMarker", _markerName, true];
        private _mkr = createMarker [_markerName, _destPos];
        _mkr setMarkerType "mil_warning";
        _mkr setMarkerColor (missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"]);
        _mkr setMarkerText "Mines";
        private _grid = mapGridPosition _destPos;
        _player setVariable ["FADE_myMissionBrief", format ["MINE CLEARING%1%1Grid: %2. Clear all mines.", toString [10], _grid], true];
        [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#C0C0C0'>Clear all mines.</t>", _grid]] call _showAssignedHint;
        [_player, "Mine Clearing"] call FADE_notifyOthersMissionStarted;
        [_taskId, _mines, _markerName, _player] spawn {
            params ["_taskId", "_mines", "_markerName", "_player"];
            waitUntil { sleep 2; { !isNull _x } count _mines == 0 };
            [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            ["<t size='1.2' color='#90EE90'>MINES CLEARED</t><br/><br/><t color='#E0E0E0'>All mines neutralised.</t>"] remoteExec ["FADE_showMissionHint", _player];
            sleep 5;
            [_markerName] call FADE_deleteMarkerSafe;
            if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
        };
    };
};

if (_missionType == "FindClearIEDs") exitWith {
    if (count _destPos < 2) exitWith {
        [_player] call FADE_clearActiveMission;
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No road near civ zone.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _destPos < 3) then { _destPos = [(_destPos select 0), (_destPos select 1), 0] };
    private _iedClass = "IEDLandBig_F";
    if (!isClass (configFile >> "CfgVehicles" >> _iedClass)) then { _iedClass = "Land_IED_v1_F" };
    private _ied = createVehicle [_iedClass, _destPos, [], 0, "NONE"];
    _ied setPosATL _destPos;
    _ied setDir (random 360);
    [_player, _taskId, "Locate and disarm or destroy the IED.", "Find and Clear IEDs", _destPos, "destroy"] call _fnc_createMissionTask;
    private _markerName = "FADE_ied_" + _taskId;
    _player setVariable ["FADE_myMissionMarker", _markerName, true];
    private _mkr = createMarker [_markerName, _destPos];
    _mkr setMarkerType "mil_warning";
    _mkr setMarkerColor (missionNamespace getVariable ["FADE_markerColorEnemy", "ColorEAST"]);
    _mkr setMarkerText "IED";
    private _grid = mapGridPosition _destPos;
    _player setVariable ["FADE_myMissionBrief", format ["FIND AND CLEAR IED%1%1Grid: %2. Disarm or destroy. Vehicles within 10 m may trigger.", toString [10], _grid], true];
    [format ["<t color='#B0B0B0'>Grid: %1</t><br/><t color='#C0C0C0'>Disarm or destroy the IED.</t>", _grid]] call _showAssignedHint;
    [_player, "Find and Clear IEDs"] call FADE_notifyOthersMissionStarted;
    [_taskId, _ied, _markerName, _player] spawn {
        params ["_taskId", "_ied", "_markerName", "_player"];
        private _proximitySec = 0;
        while { !isNull _ied && { alive _ied } } do {
            sleep 1;
            private _playersNear = false;
            { if (isPlayer _x && { alive _x } && { _x distance _ied <= 100 }) exitWith { _playersNear = true } } forEach allPlayers;
            if (_playersNear) then {
                _proximitySec = _proximitySec + 1;
                if (_proximitySec >= 60) then {
                    _proximitySec = 0;
                    if (random 1 < 0.1) then { _ied setDamage 1 };
                };
            } else {
                _proximitySec = 0;
            };
            private _vehs = _ied nearEntities [["LandVehicle", "Air"], 10];
            if (!(_vehs isEqualTo [])) then { _ied setDamage 1 };
        };
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
        ["<t size='1.2' color='#90EE90'>IED NEUTRALISED</t><br/><br/><t color='#E0E0E0'>Mission complete.</t>"] remoteExec ["FADE_showMissionHint", _player];
        sleep 5;
        [_markerName] call FADE_deleteMarkerSafe;
        if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
    };
};

if (_missionType in ["Medical", "MedicalKAT", "MASCAS", "MASCASKAT"]) exitWith {
    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _useKAT = isClass (configFile >> "CfgPatches" >> "kat_main");
    private _isKAT = _missionType in ["MedicalKAT", "MASCASKAT"];
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    private _aceHasSetUnconscious = !isNil "ace_medical_fnc_setUnconscious";
    private _aceHasStableCheck = !isNil "ace_medical_fnc_isInStableCondition";
    if ((_isKAT && { !_useKAT }) || { !_isKAT && { !_useACE } }) then {
        [_player] call FADE_clearActiveMission;
        [format ["<t size='1.2' color='#FF6666'>MEDICAL SYSTEM REQUIRED</t><br/><br/><t color='#E0E0E0'>%1 requires %2.</t>", _missionType, if (_isKAT) then { "KAT" } else { "ACE Medical" }]] remoteExec ["FADE_showMissionHint", _player];
    } else {
        private _medObj = missionNamespace getVariable ["MEDICAL_1", objNull];
        if (isNull _medObj) then {
            [_player] call FADE_clearActiveMission;
            ["<t size='1.2' color='#FF6666'>MEDICAL_1 not found in Eden.</t>"] remoteExec ["FADE_showMissionHint", _player];
        } else {
            _destPos = getPosATL _medObj;
            _destPos = [_destPos, 0, 8, 2, 0, 0.3, 0, [], _destPos] call BIS_fnc_findSafePos;
            if (count _destPos < 2) then { _destPos = getPosATL _medObj };
            private _count = if (_missionType in ["MASCAS", "MASCASKAT"]) then { 3 + floor random 4 } else { 1 };
            private _units = [];
            private _bodyParts = ["Body", "LeftArm", "RightArm", "LeftLeg", "RightLeg"];
            private _bodyPartsLower = ["body", "leftarm", "rightarm", "leftleg", "rightleg"];
            for "_i" from 0 to (_count - 1) do {
                private _u = (createGroup _sideFriendly) createUnit [(_friendlyUnits select 0), _destPos, [], 0, "NONE"];
                private _p = _destPos getPos [2 + _i * 2, _i * 60];
                if (count _p < 3) then { _p set [2, 0] };
                _p set [2, linearConversion [0, 1, random 1, 2, 10]];
                _u setPosATL _p;
                _u setDamage 0;
                _u disableAI "MOVE";
                _u setBehaviour "CARELESS";
                _u setCaptive true;
                if (_useACE) then {
                    private _severity = random 1;
                    private _partIdx = floor random (count _bodyParts);
                    private _part = _bodyParts select _partIdx;
                    private _partLower = _bodyPartsLower select _partIdx;
                    if (_severity < 0.25) then {
                        if (_aceHasAddDamage) then { [_u, 0.2 + random 0.25, _part, "bullet", objNull] call ace_medical_fnc_addDamageToUnit } else { _u setDamage (0.2 + random 0.25) };
                        if (_aceHasAddWound) then { [_u, _partLower, ["Laceration", 1, 0, 0.2]] call ace_medical_fnc_addWound };
                    } else {
                        if (_severity < 0.75) then {
                            if (_aceHasAddDamage) then { [_u, 0.35 + random 0.3, _part, "bullet", objNull] call ace_medical_fnc_addDamageToUnit } else { _u setDamage (0.35 + random 0.3) };
                            if (_aceHasAddWound) then { [_u, _partLower, ["VelocityWound", 1, 2, 0.6]] call ace_medical_fnc_addWound };
                            private _part2Idx = floor random (count _bodyParts);
                            if (_part2Idx != _partIdx) then {
                                private _p2 = _bodyParts select _part2Idx;
                                private _p2Lower = _bodyPartsLower select _part2Idx;
                                if (_aceHasAddDamage) then { [_u, 0.25 + random 0.2, _p2, "bullet", objNull] call ace_medical_fnc_addDamageToUnit } else { _u setDamage ((damage _u) max (0.25 + random 0.2)) };
                                if (_aceHasAddWound) then { [_u, _p2Lower, ["Avulsion", 1, 1, 0.4]] call ace_medical_fnc_addWound };
                            };
                        } else {
                            if (_aceHasAddDamage) then {
                                [_u, 0.4 + random 0.25, "Body", "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                                [_u, 0.3 + random 0.2, _part, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                            } else {
                                _u setDamage (0.6 + random 0.2);
                            };
                            if (_aceHasAddWound) then {
                                [_u, "body", ["VelocityWound", 1, 2, 0.7]] call ace_medical_fnc_addWound;
                                [_u, _partLower, ["Avulsion", 1, 2, 0.5]] call ace_medical_fnc_addWound;
                            };
                        };
                    };
                    if (_aceHasSetUnconscious && { random 1 < 0.35 }) then {
                        [_u, true, 30 + random 60, false] call ace_medical_fnc_setUnconscious;
                    };
                } else {
                    _u setDamage (0.3 + random 0.4);
                };
                _units pushBack _u;
            };
            missionNamespace setVariable ["FADE_medUnits_" + _taskId, _units];
            private _title = if (_count > 1) then { "MASCAS" } else { "Medical" };
            [_player, _taskId, "Heal all casualties.", _title, _destPos, "heal"] call _fnc_createMissionTask;
            _player setVariable ["FADE_myMissionMarker", "FADE_med_" + _taskId, true];
            private _mkr = createMarker ["FADE_med_" + _taskId, _destPos];
            _mkr setMarkerType "loc_Hospital";
            _mkr setMarkerColor _markerFriendly;
            _mkr setMarkerText _title;
            _player setVariable ["FADE_myMissionBrief", format ["%1 at MEDICAL_1. Heal all. Fail if >50%% die or unit dies.", _title], true];
            [format ["<t color='#B0B0B0'>%1</t><br/><t color='#C0C0C0'>Heal all at MEDICAL_1.</t>", _title]] call _showAssignedHint;
            [_player, _title] call FADE_notifyOthersMissionStarted;
            [_taskId, _units, _player, _count, _useACE, _aceHasStableCheck] spawn {
                params ["_taskId", "_units", "_player", "_count", "_useACE", "_aceHasStableCheck"];
                private _fncHealed = if (_useACE) then {
                    if (_aceHasStableCheck) then {
                        { alive _x && (_x call ace_medical_fnc_isInStableCondition) }
                    } else {
                        { alive _x && (damage _x < 0.01) }
                    }
                } else {
                    { alive _x && (damage _x < 0.01) }
                };
                waitUntil { sleep 2; private _alive = _units select { alive _x }; private _healed = _units select _fncHealed; (count _healed >= count _units) || { (count _alive) < (ceil (count _units / 2)) } };
                if ({ alive _x && (if (_useACE && { _aceHasStableCheck }) then { _x call ace_medical_fnc_isInStableCondition } else { damage _x < 0.01 }) } count _units >= count _units) then {
                    [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#90EE90'>ALL HEALED</t><br/><br/><t color='#E0E0E0'>Mission complete.</t>"] remoteExec ["FADE_showMissionHint", _player];
                } else {
                    [_taskId, "FAILED"] call BIS_fnc_taskSetState;
                    ["<t size='1.2' color='#FF6666'>TOO MANY CASUALTIES</t><br/><br/><t color='#E0E0E0'>Mission failed.</t>"] remoteExec ["FADE_showMissionHint", _player];
                };
                { if (!isNull _x) then { deleteVehicle _x } } forEach _units;
                missionNamespace setVariable ["FADE_medUnits_" + _taskId, nil];
                sleep 5;
                [("FADE_med_" + _taskId)] call FADE_deleteMarkerSafe;
                if (!isNull _player && { (_player getVariable ["FADE_myMissionTaskId", ""]) == _taskId }) then { [_player] call FADE_clearActiveMission };
            };
        };
    };
};
