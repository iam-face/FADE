// =============================================================================
// FADE_ObjectiveHelpers.sqf — shared objective spawn helpers (Raid + future reuse)
// =============================================================================

FADE_pickHvtCodename = {
    params [["_used", []]];
    private _pool = +(missionNamespace getVariable ["FADE_hvtCodenamePool", ["Viktor", "Dmitri", "Sergei", "Ivan", "Pavel", "Boris", "Volkov", "Kozlov"]]);
    private _avail = _pool - _used;
    if (_avail isEqualTo []) then { _avail = +_pool };
    selectRandom _avail
};

FADE_pickHostageIdentity = {
    params [["_used", []]];
    private _pool = +(missionNamespace getVariable ["FADE_hostageIdentities", ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"]]);
    if (_pool isEqualTo []) then { _pool = ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"] };
    private _avail = _pool - _used;
    if (_avail isEqualTo []) then { selectRandom _pool } else { selectRandom _avail }
};

FADE_getIdentityDisplayName = {
    params ["_identityClass"];
    private _n = getText (missionConfigFile >> "CfgIdentities" >> _identityClass >> "name");
    if (_n == "") then { _n = getText (configFile >> "CfgIdentities" >> _identityClass >> "name") };
    if (_n == "") then { _identityClass } else { _n }
};

FADE_recoverObjectClass = "Land_PlasticCase_01_small_gray_F";

FADE_getRecoverObjectDisplayName = {
    params [["_class", FADE_recoverObjectClass]];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _dn = if (isClass _cfg) then { getText (_cfg >> "displayName") } else { _class };
    if (_dn == "") then { _class } else { _dn }
};

// SMEAC line: recover-object display name + indoor / defended-building hint.
FADE_smeac_recoverObjectIntelLine = {
    params [["_objectName", ""], ["_color", "#C0C0C0"]];
    if (_objectName == "") then { _objectName = [] call FADE_getRecoverObjectDisplayName };
    format [
        "<t align='left' color='%2'>Recover: %1 — most likely indoors inside a defended building.</t>",
        _objectName,
        _color
    ]
};

FADE_objective_findBuilding = {
    params ["_pos", "_radius", "_minSlots"];
    private _buildings = (nearestObjects [_pos, ["House", "Building"], _radius]) call BIS_fnc_arrayShuffle;
    private _found = objNull;
    { if (count (_x buildingPos -1) >= _minSlots) exitWith { _found = _x } } forEach _buildings;
    _found
};

FADE_objective_findBuildingRelaxed = {
    params ["_pos", "_radius", "_preferSlots"];
    private _b = [_pos, _radius, _preferSlots] call FADE_objective_findBuilding;
    if (isNull _b) then { _b = [_pos, _radius, (_preferSlots * 0.6) max 3] call FADE_objective_findBuilding };
    if (isNull _b) then { _b = [_pos, _radius, 1] call FADE_objective_findBuilding };
    _b
};

// Try each search center (map-click missions); shuffled building list per center.
FADE_objective_findBuildingAtCenters = {
    params ["_centers", "_radius", "_minSlots", ["_shuffle", true]];
    private _found = objNull;
    {
        private _buildings = nearestObjects [_x, ["House", "Building"], _radius];
        if (_shuffle) then { _buildings = _buildings call BIS_fnc_arrayShuffle };
        {
            if (count (_x buildingPos -1) >= _minSlots) exitWith { _found = _x };
        } forEach _buildings;
        if (!isNull _found) exitWith {};
    } forEach _centers;
    _found
};

// Random or map-click building pick for standalone HVT / Hostage / etc.
FADE_objective_findBuildingForMission = {
    params [
        ["_fromMapClick", false],
        ["_searchCenters", []],
        ["_destPos", [0, 0, 0]],
        ["_buildRadius", 450],
        ["_minSlots", 10],
        ["_maxAttempts", 15],
        ["_minDist", 1000],
        ["_findPosFn", {}]
    ];
    if (_fromMapClick) exitWith {
        [_searchCenters, _buildRadius, _minSlots] call FADE_objective_findBuildingAtCenters
    };
    private _building = objNull;
    private _attempt = 0;
    private _pos = +_destPos;
    while { _attempt < _maxAttempts && { isNull _building } } do {
        _attempt = _attempt + 1;
        if (_attempt > 1 && { !(_findPosFn isEqualTo {}) }) then {
            _pos = [_minDist] call _findPosFn;
            if (count _pos >= 2) then { _pos = [(_pos select 0), (_pos select 1), (_pos param [2, 0])] };
        };
        if (count _pos >= 2) then {
            // Strict slot count — relaxed fallback (down to 1 slot) breaks HVT / Hostage garrison requirements.
            _building = [_pos, _buildRadius, _minSlots] call FADE_objective_findBuilding;
        };
    };
    _building
};

FADE_objective_garrisonBuilding = {
    params ["_building", "_skipIdx", "_count", "_sideEnemy", "_enemyUnits"];
    private _bps = _building buildingPos -1;
    private _grp = createGroup _sideEnemy;
    private _slotIdx = [];
    for "_i" from 0 to (count _bps - 1) do { if (_i != _skipIdx) then { _slotIdx pushBack _i } };
    _slotIdx = _slotIdx call BIS_fnc_arrayShuffle;
    private _n = _count min count _slotIdx;
    for "_i" from 0 to (_n - 1) do {
        private _p = _bps select (_slotIdx select _i);
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
        private _cls = _enemyUnits select (_i mod count _enemyUnits);
        private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
        if (!isNull _u) then {
            _u setPosATL _p;
            _u setUnitPos "MIDDLE";
            [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
        };
    };
    [_grp] call FAC_applyEnemyScenarioToGroup;
    _grp
};

FADE_objective_spawnPatrols = {
    params ["_center", "_radius", "_numPatrols", "_sideEnemy", "_enemyUnits", "_diffMul"];
    private _out = [];
    for "_p" from 0 to (_numPatrols - 1) do {
        private _angle = random 360;
        private _dist = 60 + random ((_radius - 60) max 1);
        private _sp = [(_center select 0) + _dist * (cos _angle), (_center select 1) + _dist * (sin _angle), 0];
        _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
        if (_sp isEqualType [] && { count _sp >= 2 }) then {
            _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
            private _size = [5 + floor random 4, _diffMul, 2] call FADE_raid_applyScale;
            private _grp = createGroup _sideEnemy;
            for "_k" from 0 to (_size - 1) do {
                private _cls = _enemyUnits select (_k mod count _enemyUnits);
                private _u = _grp createUnit [_cls, _sp, [], 0, "NONE"];
                if (!isNull _u) then { _u setPosATL _sp };
            };
            if (count units _grp > 0) then {
                [_grp] call FAC_applyEnemyScenarioToGroup;
                _grp setBehaviour "SAFE";
                for "_w" from 0 to 2 do {
                    private _a = _w * 120 + random 40;
                    private _d = 50 + random ((_radius - 50) max 1);
                    private _wp = [(_center select 0) + _d * (cos _a), (_center select 1) + _d * (sin _a), 0];
                    _wp = [[_wp, 0, 12, 3, 1, 0.4, 0, [], _wp], _wp] call FADE_findSafePosArray;
                    if (_wp isEqualType [] && { count _wp >= 2 }) then {
                        _wp = [(_wp select 0), (_wp select 1), (_wp param [2, 0])];
                        private _wpH = _grp addWaypoint [_wp, 0];
                        _wpH setWaypointType "MOVE";
                        _wpH setWaypointSpeed "LIMITED";
                        if (_w == 2) then { _wpH setWaypointType "CYCLE" };
                    };
                };
                _out pushBack _grp;
            } else { deleteGroup _grp };
        };
    };
    _out
};

FADE_objective_spawnHVTInBuilding = {
    params ["_building", "_slotIdx", "_sideEnemy", "_enemyUnits", ["_hvtCodename", ""], ["_preferOfficer", true]];
    private _bps = _building buildingPos -1;
    private _hvtPos = _bps select _slotIdx;
    if (count _hvtPos < 3) then { _hvtPos = [(_hvtPos select 0), (_hvtPos select 1), (_hvtPos param [2, 0])] };
    private _officerClasses = if (_preferOfficer) then { _enemyUnits select { ("officer" in (toLower _x)) } } else { [] };
    private _hvtClass = if (count _officerClasses > 0) then {
        selectRandom _officerClasses
    } else {
        if (count _enemyUnits > 0) then { selectRandom _enemyUnits } else { "O_Soldier_F" }
    };
    private _hvtGrp = createGroup _sideEnemy;
    private _hvt = _hvtGrp createUnit [_hvtClass, getPosATL _building, [], 0, "NONE"];
    _hvt disableAI "PATH";
    _hvt disableAI "MOVE";
    _hvt allowDamage false;
    _hvt setPos _hvtPos;
    removeAllWeapons _hvt;
    removeAllItems _hvt;
    removeHeadgear _hvt;
    if (_hvtCodename isEqualTo "") then { _hvtCodename = [] call FADE_pickHvtCodename };
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
        if (!isNull _u) then { _u allowDamage true };
    };
    _hvt setUnitPos "MIDDLE";
    [_hvt, "SIT_LOW", "NONE", { !alive _this }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    [_hvt, _hvtGrp, _hvtCodename, _hvtClass]
};

FADE_objective_spawnHostageInBuilding = {
    params ["_building", "_hostageIdx", ["_identityKey", ""]];
    private _bps = _building buildingPos -1;
    private _hPos = _bps select _hostageIdx;
    if (count _hPos < 3) then { _hPos = [(_hPos select 0), (_hPos select 1), (_hPos param [2, 0])] };
    private _civClasses = +(missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"]]);
    if (_civClasses isEqualTo []) then { _civClasses = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
    private _hostageIdPool = +(missionNamespace getVariable ["FADE_hostageIdentities", ["FADE_hostage_PhilCassidy", "FADE_hostage_WarrenWazzaDriscoll"]]);
    private _hostageGrp = createGroup CIVILIAN;
    private _hostage = _hostageGrp createUnit [selectRandom _civClasses, _hPos, [], 0, "NONE"];
    if (_identityKey isEqualTo "" && { count _hostageIdPool > 0 }) then { _identityKey = selectRandom _hostageIdPool };
    if !(_identityKey isEqualTo "") then { _hostage setIdentity _identityKey };
    removeAllWeapons _hostage;
    removeAllItems _hostage;
    removeHeadgear _hostage;
    removeGoggles _hostage;
    _hostage addGoggles "G_Blindfold_01_black_F";
    _hostage disableAI "PATH";
    _hostage setUnitPos "MIDDLE";
    _hostage switchMove "Acts_ExecutionVictim_Loop";
    [_hostage, _hostageGrp]
};

// Add blindfolded hostage to an existing civilian group (multi-hostage missions).
FADE_objective_addHostageToGroup = {
    params ["_hostageGroup", "_building", "_slotIdx", ["_identityKey", ""]];
    private _bps = _building buildingPos -1;
    private _hPos = _bps select _slotIdx;
    if (count _hPos < 3) then { _hPos = [(_hPos select 0), (_hPos select 1), (_hPos param [2, 0])] };
    private _civClasses = +(missionNamespace getVariable ["FADE_civUnitClasses", ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"]]);
    if (_civClasses isEqualTo []) then { _civClasses = ["C_man_1", "C_man_1_1_F", "C_man_polo_1_F"] };
    private _hostage = _hostageGroup createUnit [selectRandom _civClasses, _hPos, [], 0, "NONE"];
    if !(_identityKey isEqualTo "") then { _hostage setIdentity _identityKey };
    removeAllWeapons _hostage;
    removeAllItems _hostage;
    removeHeadgear _hostage;
    removeGoggles _hostage;
    _hostage addGoggles "G_Blindfold_01_black_F";
    _hostage disableAI "PATH";
    _hostage setUnitPos "MIDDLE";
    _hostage switchMove "Acts_ExecutionVictim_Loop";
    [_hostage, name _hostage]
};

// Garrison specific building slot indices (hostage missions).
FADE_objective_garrisonBuildingSlots = {
    params ["_building", "_slotIndices", "_sideEnemy", "_enemyUnits"];
    private _bps = _building buildingPos -1;
    private _grp = createGroup _sideEnemy;
    {
        private _p = _bps select _x;
        if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
        private _cls = _enemyUnits select (_forEachIndex mod count _enemyUnits);
        private _u = _grp createUnit [_cls, _p, [], 0, "NONE"];
        _u setUnitPos "MIDDLE";
        [_u, "STAND", "FULL", { behaviour _this == "COMBAT" || { !alive _this } }, "COMBAT"] call BIS_fnc_ambientAnimCombat;
    } forEach _slotIndices;
    if (count units _grp > 0) then {
        [_grp] call FAC_applyEnemyScenarioToGroup;
        _grp
    } else {
        deleteGroup _grp;
        grpNull
    };
};

// Find N+ buildings with min interior slots (map-click or random urban retry).
FADE_objective_findBuildingsWithMinSlots = {
    params [
        ["_fromMapClick", false],
        ["_searchCenter", [0, 0, 0]],
        ["_destPos", [0, 0, 0]],
        ["_buildRadius", 450],
        ["_minSlots", 5],
        ["_minCount", 2],
        ["_maxAttempts", 50],
        ["_minDist", 1000],
        ["_findPosFn", {}]
    ];
    private _found = [];
    if (_fromMapClick) then {
        _found = (nearestObjects [_searchCenter, ["House", "Building"], _buildRadius]) select {
            count (_x buildingPos -1) >= _minSlots
        };
    } else {
        private _attempt = 0;
        while { _attempt < _maxAttempts && { count _found < _minCount } } do {
            _attempt = _attempt + 1;
            private _pos = [_minDist] call _findPosFn;
            if (count _pos >= 2) then {
                private _buildings = nearestObjects [_pos, ["House", "Building"], _buildRadius];
                _found = _buildings select { count (_x buildingPos -1) >= _minSlots };
            };
        };
    };
    _found
};

// Two patrol groups per building around a tight ring (Hostage-style).
FADE_objective_spawnPatrolsPerBuilding = {
    params [
        "_buildings",
        "_sideEnemy",
        "_enemyUnits",
        "_scaleFn",
        ["_patrolsPerBuilding", 2],
        ["_baseDist", 80],
        ["_distVariance", 40],
        ["_patrolSizeBase", 2],
        ["_patrolSizeRand", 3]
    ];
    private _out = [];
    {
        private _building = _x;
        private _buildingCenter = getPosATL _building;
        if (count _buildingCenter < 3) then { _buildingCenter = [(_buildingCenter select 0), (_buildingCenter select 1), 0] };
        for "_pg" from 0 to (_patrolsPerBuilding - 1) do {
            private _angle = random 360;
            private _dist = _baseDist + (random (2 * _distVariance) - _distVariance);
            if (_dist < 40) then { _dist = 40 };
            private _sp = [
                (_buildingCenter select 0) + _dist * (cos _angle),
                (_buildingCenter select 1) + _dist * (sin _angle),
                0
            ];
            _sp = [[_sp, 0, 15, 3, 1, 0.4, 0, [], _sp], _sp] call FADE_findSafePosArray;
            if (_sp isEqualType [] && { count _sp >= 2 }) then {
                _sp = [(_sp select 0), (_sp select 1), (_sp param [2, 0])];
                private _patrolSize = [_patrolSizeBase + floor random _patrolSizeRand, 1] call _scaleFn;
                private _patrolClasses = (_enemyUnits select [0, _patrolSize min count _enemyUnits]);
                for "_k" from (count _patrolClasses) to (_patrolSize - 1) do { _patrolClasses pushBack (_enemyUnits select 0) };
                private _grp = [_sp, _sideEnemy, _patrolClasses] call FADE_missionCreateInfantryGroupAt;
                if (!isNull _grp) then {
                    [_grp] call FAC_applyEnemyScenarioToGroup;
                    [_grp, _buildingCenter, 40, _baseDist + _distVariance, 4, 0, 90] call FADE_missionApplyPatrolCycle;
                    _out pushBack _grp;
                };
            };
        };
    } forEach _buildings;
    _out
};

FADE_objective_addRecoverHoldAction = {
    params ["_objCase", "_taskId"];
    missionNamespace setVariable ["FADE_assetIntelTaken_" + _taskId, false];
    _objCase setVariable ["FADE_recoverTaskId", _taskId, true];
    _objCase addAction [
        "Pick up",
        {
            private _cTaskId = (_this select 0) getVariable ["FADE_recoverTaskId", ""];
            [_cTaskId, _this select 0, _this select 1] remoteExec ["FADE_assetIntelTakeServer", 2];
        },
        [],
        1.5,
        true,
        true,
        "",
        "(_this distance _target) < 3 && { alive _this } && { alive _target }",
        3
    ];
};

// Lazy-load nearby building garrisons + barrel hints (HVT / Hostage pattern).
FADE_objective_registerNearbyGarrisons = {
    params [
        "_missionTaskId",
        "_anchorBuilding",
        "_zoneCenter",
        "_groupsRef",
        "_barrelsRef",
        "_enemyUnits",
        "_diffMul",
        ["_searchRadius", -1],
        ["_maxBuildings", -1],
        ["_emptyFallbackMax", -1],
        ["_excludeBuildings", []]
    ];
    private _vgFn = missionNamespace getVariable ["FADE_vg_register", {}];
    if (_vgFn isEqualTo {}) exitWith {};
    if (isNull _anchorBuilding && { count _zoneCenter < 2 }) exitWith {};

    private _surroundRadius = if (_searchRadius > 0) then {
        _searchRadius
    } else {
        missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450]
    };
    private _surroundBChance = missionNamespace getVariable ["FADE_garrisonMissionNearbyBuildingChance", 0.25];
    private _surroundFull = (nearestObjects [_zoneCenter, ["House", "Building"], _surroundRadius] select {
        !(_x in _excludeBuildings) &&
        { isNull _anchorBuilding || { !(_x isEqualTo _anchorBuilding) } } &&
        { count (_x buildingPos -1) >= 1 }
    });
    private _surroundBuildings = _surroundFull select { random 1 < _surroundBChance };
    if (count _surroundBuildings == 0 && { count _surroundFull > 0 }) then {
        if (_emptyFallbackMax < 0) then {
            _surroundBuildings = +_surroundFull;
        } else {
            private _shuffled = _surroundFull call BIS_fnc_arrayShuffle;
            _surroundBuildings = _shuffled select [0, (_emptyFallbackMax min count _shuffled)];
        };
    };
    if (_maxBuildings > 0 && { count _surroundBuildings > _maxBuildings }) then {
        _surroundBuildings = (_surroundBuildings call BIS_fnc_arrayShuffle) select [0, _maxBuildings];
    };

    {
        private _bld = _x;
        private _bldPos = _bld buildingPos -1;
        if (_bldPos isEqualTo []) then {} else {
            private _cnt = ([1 + floor random 3, _diffMul, 1] call FADE_raid_applyScale) min count _bldPos;
            private _indices = [];
            for "_i" from 0 to (count _bldPos - 1) do { _indices pushBack _i };
            _indices = _indices call BIS_fnc_arrayShuffle;
            private _slotATL = [];
            for "_i" from 0 to (_cnt - 1) do {
                private _p = _bldPos select (_indices select _i);
                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), (_p param [2, 0])] };
                _slotATL pushBack _p;
            };
            if (count _slotATL > 0) then {
                private _st = createHashMap;
                _st set ["owner", format ["mis:%1", _missionTaskId]];
                _st set ["groupsRef", _groupsRef];
                _st set ["tryBarrel", true];
                _st set ["barrelMinDistPlayersM", -1];
                _st set ["barrelRoll", missionNamespace getVariable ["FADE_vgLazyOutdoorHintChance", 0.5]];
                _st set ["barrelClasses", missionNamespace getVariable ["FADE_vgLazyOutdoorHintClasses", ["MetalBarrel_burning_F"]]];
                private _bCh = getPosATL _bld;
                if (count _bCh < 3) then { _bCh = [(_bCh select 0), (_bCh select 1), 0] };
                _st set ["barrelCenter", _bCh];
                _st set ["barrelsRef", _barrelsRef];
                [_bld, _slotATL, +_enemyUnits, _st] call _vgFn;
            };
        };
    } forEach _surroundBuildings;
};

FADE_objective_spawnRecoverObject = {
    params ["_zoneCenter", "_buildRadius", "_objMinSlots", "_sideEnemy", "_enemyUnits", "_diffMul", ["_patrolRadius", 200]];
    private _bld = [_zoneCenter, _buildRadius, _objMinSlots] call FADE_objective_findBuildingRelaxed;
    if (isNull _bld) exitWith { [false, [], [], [0, 0, 0], []] };

    private _bps = _bld buildingPos -1;
    private _objIdx = if (count _bps >= 3) then { 1 + floor random ((count _bps) - 2) } else { 0 };
    private _objPos = _bps select _objIdx;
    if (count _objPos < 3) then { _objPos = [(_objPos select 0), (_objPos select 1), (_objPos param [2, 0])] };
    private _objCase = createVehicle [FADE_recoverObjectClass, _objPos, [], 0, "NONE"];
    _objCase setPosATL _objPos;
    _objCase setDir (getDir _bld);

    private _guardCount = [6 + floor random 4, _diffMul, 2] call FADE_raid_applyScale;
    private _zoneGroups = [[_bld, _objIdx, _guardCount, _sideEnemy, _enemyUnits] call FADE_objective_garrisonBuilding];
    _zoneGroups append ([_zoneCenter, _patrolRadius, ([1 + floor random 3, _diffMul, 1] call FADE_raid_applyScale), _sideEnemy, _enemyUnits, _diffMul] call FADE_objective_spawnPatrols);
    [true, _zoneGroups, [_objCase], getPosATL _bld, []]
};

FADE_objective_spawnKillHVT = {
    params ["_zoneCenter", "_buildRadius", "_hvtMinSlots", "_sideEnemy", "_enemyUnits", "_diffMul", ["_patrolRadius", 200], ["_hvtCodename", ""]];
    private _bld = [_zoneCenter, _buildRadius, _hvtMinSlots] call FADE_objective_findBuildingRelaxed;
    if (isNull _bld) exitWith { [false, [], [], [0, 0, 0], []] };

    private _bps = _bld buildingPos -1;
    private _hvtIdx = if (count _bps >= 3) then { 1 + floor random ((count _bps) - 2) } else { 0 };
    private _hvtData = [_bld, _hvtIdx, _sideEnemy, _enemyUnits, _hvtCodename] call FADE_objective_spawnHVTInBuilding;
    _hvtData params ["_hvt", "_hvtGrp"];

    private _guardCount = [6 + floor random 4, _diffMul, 2] call FADE_raid_applyScale;
    private _zoneGroups = [_hvtGrp, [_bld, _hvtIdx, _guardCount, _sideEnemy, _enemyUnits] call FADE_objective_garrisonBuilding];
    _zoneGroups append ([_zoneCenter, _patrolRadius, ([1 + floor random 3, _diffMul, 1] call FADE_raid_applyScale), _sideEnemy, _enemyUnits, _diffMul] call FADE_objective_spawnPatrols);
    [true, _zoneGroups, [], getPosATL _bld, [_hvt]]
};

FADE_objective_spawnCaptureHVT = {
    params ["_zoneCenter", "_buildRadius", "_hvtMinSlots", "_sideEnemy", "_enemyUnits", "_diffMul", ["_patrolRadius", 200], ["_hvtCodename", ""]];
    [_zoneCenter, _buildRadius, _hvtMinSlots, _sideEnemy, _enemyUnits, _diffMul, _patrolRadius, _hvtCodename] call FADE_objective_spawnKillHVT
};

FADE_objective_spawnRecoverHostage = {
    params ["_zoneCenter", "_buildRadius", "_hostageMinSlots", "_sideEnemy", "_enemyUnits", "_diffMul", ["_patrolRadius", 200], ["_hostageIdentity", ""]];
    private _bld = [_zoneCenter, _buildRadius, _hostageMinSlots] call FADE_objective_findBuildingRelaxed;
    if (isNull _bld) exitWith { [false, [], [], [0, 0, 0], []] };

    private _bps = _bld buildingPos -1;
    private _hIdx = floor ((count _bps) / 2);
    private _hostageData = [_bld, _hIdx, _hostageIdentity] call FADE_objective_spawnHostageInBuilding;
    _hostageData params ["_hostage", "_hostageGrp"];

    private _guardCount = [5 + floor random 4, _diffMul, 2] call FADE_raid_applyScale;
    private _zoneGroups = [_hostageGrp, [_bld, _hIdx, _guardCount, _sideEnemy, _enemyUnits] call FADE_objective_garrisonBuilding];
    _zoneGroups append ([_zoneCenter, _patrolRadius, ([1 + floor random 3, _diffMul, 1] call FADE_raid_applyScale), _sideEnemy, _enemyUnits, _diffMul] call FADE_objective_spawnPatrols);
    [true, _zoneGroups, [], getPosATL _bld, [_hostage]]
};

missionNamespace setVariable ["FADE_pickHvtCodename", FADE_pickHvtCodename];
missionNamespace setVariable ["FADE_pickHostageIdentity", FADE_pickHostageIdentity];
missionNamespace setVariable ["FADE_getIdentityDisplayName", FADE_getIdentityDisplayName];
missionNamespace setVariable ["FADE_recoverObjectClass", FADE_recoverObjectClass];
missionNamespace setVariable ["FADE_getRecoverObjectDisplayName", FADE_getRecoverObjectDisplayName];
missionNamespace setVariable ["FADE_smeac_recoverObjectIntelLine", FADE_smeac_recoverObjectIntelLine];
missionNamespace setVariable ["FADE_objective_findBuilding", FADE_objective_findBuilding];
missionNamespace setVariable ["FADE_objective_findBuildingRelaxed", FADE_objective_findBuildingRelaxed];
missionNamespace setVariable ["FADE_objective_findBuildingAtCenters", FADE_objective_findBuildingAtCenters];
missionNamespace setVariable ["FADE_objective_findBuildingForMission", FADE_objective_findBuildingForMission];
missionNamespace setVariable ["FADE_objective_garrisonBuilding", FADE_objective_garrisonBuilding];
missionNamespace setVariable ["FADE_objective_spawnPatrols", FADE_objective_spawnPatrols];
missionNamespace setVariable ["FADE_objective_spawnHVTInBuilding", FADE_objective_spawnHVTInBuilding];
missionNamespace setVariable ["FADE_objective_spawnHostageInBuilding", FADE_objective_spawnHostageInBuilding];
missionNamespace setVariable ["FADE_objective_addHostageToGroup", FADE_objective_addHostageToGroup];
missionNamespace setVariable ["FADE_objective_garrisonBuildingSlots", FADE_objective_garrisonBuildingSlots];
missionNamespace setVariable ["FADE_objective_findBuildingsWithMinSlots", FADE_objective_findBuildingsWithMinSlots];
missionNamespace setVariable ["FADE_objective_spawnPatrolsPerBuilding", FADE_objective_spawnPatrolsPerBuilding];
missionNamespace setVariable ["FADE_objective_addRecoverHoldAction", FADE_objective_addRecoverHoldAction];
missionNamespace setVariable ["FADE_objective_registerNearbyGarrisons", FADE_objective_registerNearbyGarrisons];
missionNamespace setVariable ["FADE_objective_spawnRecoverObject", FADE_objective_spawnRecoverObject];
missionNamespace setVariable ["FADE_objective_spawnKillHVT", FADE_objective_spawnKillHVT];
missionNamespace setVariable ["FADE_objective_spawnCaptureHVT", FADE_objective_spawnCaptureHVT];
missionNamespace setVariable ["FADE_objective_spawnRecoverHostage", FADE_objective_spawnRecoverHostage];
