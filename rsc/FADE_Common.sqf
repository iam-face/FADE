// =============================================================================
// FADE_Common.sqf  -  shared helpers (server boot; compiled from initServer)
// =============================================================================

FADE_normPos3 = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    if (count _p < 3) then { [(_p select 0), (_p select 1), 0] } else { _p }
};

FADE_surfaceIsDry = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
    !surfaceIsWater [_p select 0, _p select 1]
};

// Empty until the player base is committed. Altis sets the flag during Eden init.
FADE_getPlayerBasePos = {
    if !(missionNamespace getVariable ["FADE_baseDefined", false]) exitWith { [] };
    private _p = missionNamespace getVariable ["FADE_basePos", []];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [] };
    _p
};

// true when the caller should stop. Chats the player if the base is not committed yet.
FADE_base_denyUntilDefined = {
    params [["_player", objNull]];
    if (missionNamespace getVariable ["FADE_baseDefined", false]) exitWith { false };
    if (!isNull _player && { isPlayer _player }) then {
        ["Player base is not set yet."] remoteExec ["systemChat", _player];
    };
    true
};

// Single BIS_fnc_findSafePos attempt; returns [] if result is missing or on water.
FADE_findLandPosWithArgs = {
    params ["_landArgs"];
    private _r = _landArgs call BIS_fnc_findSafePos;
    if (!(_r isEqualType []) || { count _r < 2 }) exitWith { [] };
    private _out = [_r] call FADE_normPos3;
    if ([_out] call FADE_surfaceIsDry) then { _out } else { [] }
};

// Snap _pos to dry land near _anchor (spiral search). Used before infantry spawn.
FADE_ensureDryLandPos = {
    params [["_pos", [0, 0, 0]], ["_anchor", []], ["_maxAttempts", 28]];
    private _p = [_pos] call FADE_normPos3;
    if ([_p] call FADE_surfaceIsDry) exitWith { _p };
    private _anchorPos = if (_anchor isEqualTo [] || { count _anchor < 2 }) then { _p } else { [_anchor] call FADE_normPos3 };
    for "_i" from 1 to _maxAttempts do {
        private _dist = 10 + (_i * 15) + random 25;
        private _ang = (_i * 41) mod 360;
        private _try = [_anchorPos, _dist, _ang] call BIS_fnc_relPos;
        private _cand = [[_try, 0, 12, 3, 0, 0.45, 0, [], _try], _try] call FADE_findLandPosWithArgs;
        if (_cand isEqualType [] && { count _cand >= 2 }) exitWith { _p = _cand };
    };
    _p
};

FADE_findSafePosArray = {
    params ["_args", "_fallback"];
    private _landArgs = +_args;
    // BIS water mode (index 4): 0=land, 1=water, 2=either. Legacy calls used 1 by mistake.
    if (count _landArgs >= 5 && { (_landArgs select 4) == 1 }) then {
        _landArgs set [4, 0];
    } else {
        if (count _landArgs < 5) then { _landArgs pushBack 0 };
    };
    private _fb = [_fallback] call FADE_normPos3;
    private _center = [_landArgs param [0, _fb]] call FADE_normPos3;
    private _first = [_landArgs] call FADE_findLandPosWithArgs;
    if (count _first >= 2) exitWith { _first };

    private _minD = _landArgs param [1, 0];
    private _maxD = (_landArgs param [2, 50]) max 30;
    private _objD = _landArgs param [3, 3];
    private _maxGrad = _landArgs param [5, 0.45];
    private _blacklist = _landArgs param [7, []];
    private _result = [];
    for "_i" from 1 to 24 do {
        private _expand = (_i - 1) * 30;
        private _ang = (_i * 43) mod 360;
        private _dist = _minD + random ((_maxD + _expand) - _minD max 1);
        private _tryC = [_center, _dist, _ang] call BIS_fnc_relPos;
        private _tryArgs = [_tryC, _minD, _maxD + _expand, _objD, 0, _maxGrad, 0, _blacklist, _center];
        private _cand = [_tryArgs] call FADE_findLandPosWithArgs;
        if (count _cand >= 2) exitWith { _result = _cand };
    };
    if (count _result >= 2) exitWith { _result };
    [_center, _fb] call FADE_ensureDryLandPos
};

// True when _pos sits on a road surface or within _clearM of a road segment (barrel/campfire hints).
FADE_posOnOrNearRoad = {
    params ["_pos", ["_clearM", 8]];
    private _p = [_pos] call FADE_normPos3;
    isOnRoad _p || { count (_p nearRoads _clearM) > 0 }
};

// Outdoor garrison hint position (burning barrel / campfire) near a building anchor, avoiding roads.
FADE_findOutdoorHintPos = {
    params [
        "_center",
        ["_minDist", 8],
        ["_maxDist", 22],
        ["_maxAttempts", 20],
        ["_roadClearM", -1]
    ];
    private _c = [_center] call FADE_normPos3;
    if (_roadClearM < 0) then {
        _roadClearM = missionNamespace getVariable ["FADE_vgOutdoorHintRoadClearM", 8];
    };
    private _result = [];
    for "_i" from 1 to _maxAttempts do {
        private _expand = (_i - 1) * 5;
        private _ang = (_i * 47) mod 360;
        private _seed = if (_i == 1) then {
            _c
        } else {
            [_c, _minDist + random ((_maxDist + _expand) - _minDist max 1), _ang] call BIS_fnc_relPos
        };
        private _cand = [[_seed, _minDist, _maxDist + _expand, 2, 0, 0.3, 0, [], _seed], _seed] call FADE_findSafePosArray;
        if (count _cand >= 2) then {
            _cand = [_cand] call FADE_normPos3;
            if !([_cand, _roadClearM] call FADE_posOnOrNearRoad) exitWith { _result = _cand };
        };
    };
    _result
};

FADE_jitterMarkerPos = {
    params [["_pos", [0, 0, 0]], ["_radiusM", 100]];
    private _p = [_pos] call FADE_normPos3;
    if (_radiusM <= 0) exitWith { +_p };
    private _j = [_p, random _radiusM, random 360] call BIS_fnc_relPos;
    [(_j select 0), (_j select 1), (_p select 2)]
};

FADE_missionOutcomeHint = {
    params ["_player", "_title", "_body", ["_color", "#FF6666"]];
    if (isNull _player) exitWith {};
    [format [
        "<t size='1.2' color='%3'>%1</t><br/><br/><t color='#E0E0E0'>%2</t>",
        _title,
        _body,
        _color
    ]] remoteExec ["FADE_showMissionHint", _player];
};

FADE_missionErrorHint = {
    params ["_player", "_title", "_body"];
    [_player, _title, _body, "#FF6666"] call FADE_missionOutcomeHint;
};

// Server gate for mission starts. True when the player may open the missions GUI.
FADE_mission_requireGuiAccess = {
    params ["_player"];
    if ([_player] call FADE_playerCanUseMissionsGui) exitWith { true };
    ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    false
};

FADE_missionFailHint = {
    params ["_player", "_body"];
    [_player, "MISSION FAILED", _body, "#FF6666"] call FADE_missionOutcomeHint;
};

FADE_missionSuccessHint = {
    params ["_player", "_body"];
    [_player, "MISSION COMPLETE", _body, "#90EE90"] call FADE_missionOutcomeHint;
};

// Procedural texture string helpers (MOTD board, HQ main board, etc.).
FADE_textureText_sanitize = {
    params [["_text", ""]];
    if (!(_text isEqualType "")) then { _text = str _text };
    private _out = [];
    {
        switch (_x) do {
            case 34: { _out append (toArray "'") };
            case 92: { _out pushBack 47 };
            case 10;
            case 13;
            case 9: { _out pushBack 32 };
            default { _out pushBack _x };
        };
    } forEach (toArray _text);
    toString _out
};

FADE_textureText_wrap = {
    params [["_text", ""], ["_maxChars", 40], ["_newline", toString [92, 110]]];
    if (_text == "") exitWith { "" };
    private _words = _text splitString " ";
    private _lines = [];
    private _line = "";
    {
        private _word = _x;
        private _test = if (_line == "") then { _word } else { _line + " " + _word };
        if ((count _test) > _maxChars && { _line != "" }) then {
            _lines pushBack _line;
            _line = _word;
        } else {
            _line = _test;
        };
    } forEach _words;
    if (_line != "") then { _lines pushBack _line };
    _lines joinString _newline
};

FADE_missionSlotGateHint = {
    params ["_player", "_reason"];
    if (isNull _player) exitWith {};
    private _html = switch (_reason) do {
        case "active": {
            "<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have an active mission. Abort it before starting another.</t>"
        };
        case "global": {
            "<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>Another global mission is in progress. Abort it or wait for completion.</t>"
        };
        case "slotsFull": {
            "<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>All single-mission slots are in use. Abort a mission or wait.</t>"
        };
        default {
            "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Cannot start mission.</t>"
        };
    };
    [_html] remoteExec ["FADE_showMissionHint", _player];
};

// Road heading at _pos; optional _dirToward picks the lane that faces that point.
FADE_opforGroundVehicleRoadDirAt = {
    params ["_pos", ["_dirToward", []]];
    private _posN = [_pos] call FADE_normPos3;
    private _roads = (_posN nearRoads 12) select { !isNull _x };
    if (_roads isEqualTo []) exitWith { 0 };
    private _r0 = _roads select 0;
    private _conn = roadsConnectedTo _r0;
    private _dir = if (count _conn > 0) then {
        [getPosATL _r0, getPosATL (_conn select 0)] call BIS_fnc_dirTo
    } else {
        getDir _r0
    };
    if (count _dirToward >= 2) then {
        private _faceDir = _posN getDir _dirToward;
        private _delta = ((_dir - _faceDir + 540) mod 360) - 180;
        if (abs _delta > 90) then { _dir = (_dir + 180) mod 360 };
    };
    _dir
};

// Nearest clear road slot for OPFOR ground vehicles. Returns [posATL, dirDeg] or [].
// Air/ship/static spawns must not use this helper.
FADE_findOpforGroundVehicleRoadSpawn = {
    params [
        "_anchor",
        ["_roadSearchM", 450],
        ["_existingVehs", []],
        ["_minDistFromRef", -1],
        ["_refPoint", []],
        ["_dirToward", []],
        ["_minVehGap", 12],
        ["_objClear", 8],
        ["_terrainClear", 10]
    ];
    private _dryFn = missionNamespace getVariable ["FADE_surfaceIsDry", { params ["_p"]; count _p >= 2 && { !surfaceIsWater [_p select 0, _p select 1] } }];
    private _anchorN = [_anchor] call FADE_normPos3;
    private _refN = if (count _refPoint >= 2) then { [_refPoint] call FADE_normPos3 } else { [] };

    private _result = [];
    private _roads = _anchorN nearRoads _roadSearchM;
    if !(_roads isEqualTo []) then {
        // nearRoads in towns can return hundreds; sorting all of them stalls mission start
        if (count _roads > 36) then {
            _roads = _roads call BIS_fnc_arrayShuffle;
            _roads = _roads select [0, 36];
        };
        _roads = [_roads, [], { (getPosATL _x) distance2D _anchorN }, "ASCEND"] call BIS_fnc_sortBy;

        private _maxRoadTries = (count _roads) min 12;
        private _best = [];
        private _bestDir = 0;

        // Do not declare private inside this for+continue loop (SQF re-entry bug).
        private _roadPos = [0, 0, 0];
        private _nearVeh = [];
        private _blacklist = [];
        private _probe = [0, 0, 0];
        private _terr = [];
        private _nearStatic = [];
        private _tooClose = false;
        private _block = [];

        scopeName "FADE_opforRoadSpawn";
        private _blPos = [0, 0, 0];
        for "_ri" from 0 to (_maxRoadTries - 1) do {
            _roadPos = getPosATL (_roads select _ri);
            if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
            if !([_roadPos] call _dryFn) then { continue };
            if (_minDistFromRef >= 0 && { count _refN >= 2 } && { _roadPos distance2D _refN <= _minDistFromRef }) then { continue };

            _nearVeh = nearestObjects [_roadPos, ["LandVehicle", "Air", "Ship"], _minVehGap + 5];
            _blacklist = [];
            {
                if (!isNull _x && { alive _x }) then {
                    _blPos = getPosATL _x;
                    _blacklist pushBack [(_blPos select 0), (_blPos select 1), _minVehGap];
                };
            } forEach (_nearVeh + _existingVehs);

            _probe = [[_roadPos, 0, 6, _objClear, 0, 0.35, 0, _blacklist, _roadPos], _roadPos] call FADE_findSafePosArray;
            if (!(_probe isEqualType []) || { count _probe < 2 } || { !([_probe] call _dryFn) }) then { continue };
            if (count _probe < 3) then { _probe = [(_probe select 0), (_probe select 1), 0] };

            if !(isOnRoad _probe || { count (_probe nearRoads 10) > 0 }) then { continue };

            _terr = nearestTerrainObjects [_probe, ["HOUSE", "BUILDING", "WALL", "FENCE", "ROCK", "BUSH", "TREE"], _terrainClear, false, true];
            if (count _terr > 0) then { continue };

            _nearStatic = nearestObjects [_probe, ["House", "Building", "Wall", "Rock"], _terrainClear];
            if (count _nearStatic > 0) then { continue };

            _tooClose = false;
            {
                if (!isNull _x && { alive _x } && { (_x distance2D _probe) < _minVehGap }) then { _tooClose = true };
            } forEach _existingVehs;
            if (_tooClose) then { continue };

            _block = nearestObjects [_probe, ["LandVehicle", "Air"], _minVehGap] select { alive _x };
            if (count _block > 0) then { continue };

            _best = _probe;
            _bestDir = [_probe, _dirToward] call FADE_opforGroundVehicleRoadDirAt;
            breakOut "FADE_opforRoadSpawn";
        };

        if (count _best >= 2) then { _result = [_best, _bestDir] };
    };
    _result
};

// Create or crew a ground vehicle. Returns [vehicle, crewGroup, cargoGroup].
// _roles: "driver", "gunner", "commander", "cargo".
// _classPick: "random" or "ordered" (driver, gunner, commander, then cargo, in list order).
// _cargoLimit -1 fills every empty cargo seat. _velocityHeading -1 uses _spawnDir.
// _engineOn: -1 leave, 0 off, 1 on. _existingVeh crews that vehicle instead of creating one.
// Does not set behaviour or waypoints. Applies enemy scenario skill to crew groups.
FADE_spawnCrewedGroundVehicle = {
    params [
        "_className",
        "_spawnPos",
        "_spawnDir",
        "_unitClasses",
        "_side",
        ["_roles", ["driver", "gunner", "commander"]],
        ["_classPick", "random"],
        ["_cargoOwnGroup", true],
        ["_cargoLimit", -1],
        ["_velocity", 0],
        ["_velocityHeading", -1],
        ["_engineOn", -1],
        ["_registerTaskId", ""],
        ["_requireDriver", false],
        ["_ensureGunner", true],
        ["_existingVeh", objNull],
        ["_deleteVehIfNoCrew", false]
    ];
    if (!(_unitClasses isEqualType [])) then { _unitClasses = [] };
    if (!(_roles isEqualType [])) then { _roles = ["driver", "gunner", "commander"] };
    if (isNull _existingVeh && { !(_className isEqualType "") || { _className == "" } }) exitWith { [objNull, grpNull, grpNull] };
    if (count _spawnPos < 2) exitWith { [objNull, grpNull, grpNull] };
    if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };

    private _veh = _existingVeh;
    private _created = false;
    if (isNull _veh) then {
        _veh = createVehicle [_className, _spawnPos, [], 0, "NONE"];
        _created = true;
    };
    if (isNull _veh) exitWith { [objNull, grpNull, grpNull] };
    if (_created) then {
        _veh setPosATL _spawnPos;
        _veh setDir _spawnDir;
        _veh setVectorUp surfaceNormal _spawnPos;
        if (_velocity != 0) then {
            private _heading = if (_velocityHeading >= 0) then { _velocityHeading } else { _spawnDir };
            _veh setVelocity [(sin _heading) * _velocity, (cos _heading) * _velocity, 0];
        };
        if (_engineOn == 0) then { _veh engineOn false };
        if (_engineOn == 1) then { _veh engineOn true };
    };

    private _ord = 0;
    private _pool = [_unitClasses] call FADE_filterInfantryManClasses;
    private _nextClass = {
        if (_classPick == "ordered") then {
            if (_unitClasses isEqualTo []) exitWith { "" };
            private _raw = _unitClasses select (_ord min ((count _unitClasses) - 1));
            _ord = _ord + 1;
            if ([_raw] call FADE_isInfantryManClass) then { _raw } else { "" }
        } else {
            if (_pool isEqualTo []) exitWith { "" };
            selectRandom _pool
        };
    };
    private _seatMan = {
        params ["_grp", "_role"];
        private _cls = [] call _nextClass;
        if (_cls == "") exitWith { objNull };
        private _man = _grp createUnit [_cls, _spawnPos, [], 0, "NONE"];
        if (isNull _man) exitWith { objNull };
        switch (_role) do {
            case "driver": {
                _man assignAsDriver _veh;
                _man moveInDriver _veh;
                _grp selectLeader _man;
            };
            case "gunner": {
                _man assignAsGunner _veh;
                _man moveInGunner _veh;
            };
            case "commander": { _man moveInCommander _veh };
            case "cargo": { _man moveInCargo _veh };
        };
        _man
    };

    private _crewGrp = createGroup _side;
    private _cargoGrp = grpNull;
    private _man = objNull;
    if ("driver" in _roles && { _veh emptyPositions "driver" > 0 }) then {
        _man = [_crewGrp, "driver"] call _seatMan;
    };
    if ("gunner" in _roles && { _veh emptyPositions "gunner" > 0 }) then {
        _man = [_crewGrp, "gunner"] call _seatMan;
    };
    if ("commander" in _roles && { _veh emptyPositions "commander" > 0 }) then {
        _man = [_crewGrp, "commander"] call _seatMan;
    };
    if ("cargo" in _roles) then {
        private _seats = (_veh emptyPositions "cargo") max 0;
        if (_cargoLimit >= 0) then { _seats = _seats min _cargoLimit };
        if (_seats > 0) then {
            private _cargoHost = _crewGrp;
            if (_cargoOwnGroup) then {
                _cargoGrp = createGroup _side;
                _cargoHost = _cargoGrp;
            };
            for "_c" from 0 to (_seats - 1) do {
                _man = [_cargoHost, "cargo"] call _seatMan;
            };
        };
    };

    private _wipeGrp = {
        params ["_grp"];
        if (isNull _grp) exitWith {};
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
        deleteGroup _grp;
    };
    if (_requireDriver && { "driver" in _roles } && { isNull driver _veh }) exitWith {
        [_crewGrp] call _wipeGrp;
        [_cargoGrp] call _wipeGrp;
        deleteVehicle _veh;
        [objNull, grpNull, grpNull]
    };

    if (_ensureGunner && { !isNil "FADE_ensureEnemyVehicleGunner" }) then {
        [_veh, _unitClasses] call FADE_ensureEnemyVehicleGunner;
    };
    private _apply = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if !(_apply isEqualTo {}) then {
        if (!isNull _crewGrp && { count units _crewGrp > 0 }) then { [_crewGrp] call _apply };
        if (!isNull _cargoGrp && { count units _cargoGrp > 0 }) then { [_cargoGrp] call _apply };
    };
    if (!isNull _crewGrp && { count units _crewGrp == 0 }) then {
        deleteGroup _crewGrp;
        _crewGrp = grpNull;
    };
    if (!isNull _cargoGrp && { count units _cargoGrp == 0 }) then {
        deleteGroup _cargoGrp;
        _cargoGrp = grpNull;
    };
    if (_deleteVehIfNoCrew && { isNull _crewGrp } && { isNull _cargoGrp }) exitWith {
        deleteVehicle _veh;
        [objNull, grpNull, grpNull]
    };
    if (_registerTaskId != "" && { !isNil "FADE_missionEnt_registerVehicle" }) then {
        [_registerTaskId, _veh] call FADE_missionEnt_registerVehicle;
    };
    [_veh, _crewGrp, _cargoGrp]
};

// Spawn one crewed OPFOR ground vehicle on a clear road near _center.
// _existingVehs is updated in place. Returns [vehicle, group] or [objNull, grpNull].
// Compiled in FADE_Common (initServer) — safe to call repeatedly from mission while/for loops.
FADE_missionSpawnOpforRoadVehicleCrewed = {
    params [
        "_center",
        ["_roadSearchM", 450],
        "_existingVehs",
        "_vehClasses",
        "_enemyUnits",
        "_sideEnemy",
        "_taskId",
        ["_wpCenter", []],
        ["_facePos", []],
        ["_addWaypoint", true]
    ];
    if (_vehClasses isEqualTo [] || { count _enemyUnits == 0 }) exitWith { [objNull, grpNull] };
    private _face = if (count _facePos >= 2) then { _facePos } else { if (count _wpCenter >= 2) then { _wpCenter } else { _center } };
    private _wpRef = if (count _wpCenter >= 2) then { _wpCenter } else { _center };
    // Single-line private+assign: split declare/assign breaks on 2+ invocations of reused code blocks.
    private _roadSpawnOut = [_center, _roadSearchM, _existingVehs, -1, [], _face] call FADE_findOpforGroundVehicleRoadSpawn;
    if (!(_roadSpawnOut isEqualType []) || { count _roadSpawnOut < 2 }) exitWith { [objNull, grpNull] };
    private _roadPos = +(_roadSpawnOut select 0);
    private _roadDir = _roadSpawnOut select 1;
    if (count _roadPos < 3) then { _roadPos = [(_roadPos select 0), (_roadPos select 1), 0] };
    private _vClass = selectRandom _vehClasses;
    private _crewPack = [
        _vClass, _roadPos, _roadDir, _enemyUnits, _sideEnemy,
        ["driver", "gunner", "commander"], "random", true, -1, 0, -1, -1, _taskId
    ] call FADE_spawnCrewedGroundVehicle;
    private _veh = _crewPack select 0;
    private _vehGrp = _crewPack select 1;
    if (isNull _veh) exitWith { [objNull, grpNull] };
    _existingVehs pushBack _veh;
    if (isNull _vehGrp) then { _vehGrp = createGroup _sideEnemy };
    _vehGrp setBehaviour "SAFE";
    _vehGrp setSpeedMode "LIMITED";
    if (_addWaypoint && { count _wpRef >= 2 }) then {
        private _wpAngle = random 360;
        private _wpDist = 30 + random 170;
        private _wpPos = [(_wpRef select 0) + _wpDist * (cos _wpAngle), (_wpRef select 1) + _wpDist * (sin _wpAngle), 0];
        _wpPos = [[_wpPos, 0, 20, 10, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
        if (_wpPos isEqualType [] && { count _wpPos >= 2 }) then {
            if (count _wpPos < 3) then { _wpPos = [(_wpPos select 0), (_wpPos select 1), 0] };
            private _wp = _vehGrp addWaypoint [_wpPos, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
        };
    };
    [_veh, _vehGrp]
};

// Flat roof ATL on a building (bbox raycast). [] if none suitable.
FADE_buildingRoofPos = {
    params ["_building", ["_minHeightM", -1]];
    if (isNull _building || { damage _building > 0.9 }) exitWith { [] };
    private _bb = 0 boundingBoxReal _building;
    private _mins = _bb select 0;
    private _maxs = _bb select 1;
    private _h = (_maxs select 2) - (_mins select 2);
    private _minH = if (_minHeightM < 0) then {
        missionNamespace getVariable ["FADE_buildingRoofMinHeightM", missionNamespace getVariable ["FADE_aaa_manpadsMinBuildingHeightM", 4]]
    } else {
        _minHeightM
    };
    if (_h < _minH) exitWith { [] };
    private _dx = ((_maxs select 0) - (_mins select 0)) max 0.1;
    private _dy = ((_maxs select 1) - (_mins select 1)) max 0.1;
    private _tries = missionNamespace getVariable ["FADE_buildingRoofSamples", missionNamespace getVariable ["FADE_aaa_manpadsRoofSamples", 10]];
    private _roof = [];
    for "_i" from 1 to _tries do {
        private _mx = (_mins select 0) + random _dx;
        private _my = (_mins select 1) + random _dy;
        private _from = _building modelToWorld [_mx, _my, (_maxs select 2) + 4];
        private _to = _building modelToWorld [_mx, _my, (_mins select 2) - 0.5];
        private _hits = lineIntersectsSurfaces [_from, _to, objNull, _building, true, 1, "VIEW", "GEOM"];
        if (_hits isEqualTo []) then { continue };
        (_hits select 0) params ["_posASL", "_norm"];
        if ((_norm select 2) < 0.65) then { continue };
        private _posATL = ASLtoATL _posASL;
        if (surfaceIsWater [_posATL select 0, _posATL select 1]) then { continue };
        _roof = _posATL;
        break;
    };
    _roof
};

missionNamespace setVariable ["FADE_normPos3", FADE_normPos3];
missionNamespace setVariable ["FADE_surfaceIsDry", FADE_surfaceIsDry];
missionNamespace setVariable ["FADE_findLandPosWithArgs", FADE_findLandPosWithArgs];
missionNamespace setVariable ["FADE_ensureDryLandPos", FADE_ensureDryLandPos];
missionNamespace setVariable ["FADE_findSafePosArray", FADE_findSafePosArray];
missionNamespace setVariable ["FADE_posOnOrNearRoad", FADE_posOnOrNearRoad];
missionNamespace setVariable ["FADE_findOutdoorHintPos", FADE_findOutdoorHintPos];
missionNamespace setVariable ["FADE_jitterMarkerPos", FADE_jitterMarkerPos];
missionNamespace setVariable ["FADE_missionErrorHint", FADE_missionErrorHint];
missionNamespace setVariable ["FADE_mission_requireGuiAccess", FADE_mission_requireGuiAccess];
missionNamespace setVariable ["FADE_missionOutcomeHint", FADE_missionOutcomeHint];
missionNamespace setVariable ["FADE_missionFailHint", FADE_missionFailHint];
missionNamespace setVariable ["FADE_missionSuccessHint", FADE_missionSuccessHint];
missionNamespace setVariable ["FADE_textureText_sanitize", FADE_textureText_sanitize];
missionNamespace setVariable ["FADE_textureText_wrap", FADE_textureText_wrap];
missionNamespace setVariable ["FADE_missionSlotGateHint", FADE_missionSlotGateHint];
missionNamespace setVariable ["FADE_opforGroundVehicleRoadDirAt", FADE_opforGroundVehicleRoadDirAt];
missionNamespace setVariable ["FADE_findOpforGroundVehicleRoadSpawn", FADE_findOpforGroundVehicleRoadSpawn];
missionNamespace setVariable ["FADE_spawnCrewedGroundVehicle", FADE_spawnCrewedGroundVehicle];
missionNamespace setVariable ["FADE_missionSpawnOpforRoadVehicleCrewed", FADE_missionSpawnOpforRoadVehicleCrewed];
missionNamespace setVariable ["FADE_buildingRoofPos", FADE_buildingRoofPos];
