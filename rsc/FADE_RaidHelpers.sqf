// =============================================================================
// FADE_RaidHelpers.sqf — variant pick, difficulty, intel refinement, zone spawn
// =============================================================================

FADE_raid_inZoneVariants = { ["RecoverObject", "KillHVT"] };
FADE_raid_rtbVariants = { ["CaptureHVT", "RecoverHostage"] };

FADE_raid_variantLabels = createHashMapFromArray [
    ["RecoverObject", "Recover Object"],
    ["KillHVT", "Eliminate HVT"],
    ["CaptureHVT", "Capture HVT"],
    ["RecoverHostage", "Recover Hostage"]
];

FADE_raid_pickCellName = {
    params ["_taskId"];
    private _pool = missionNamespace getVariable ["FADE_raidCellNames", [
        "Volkov cell", "Kozlov network", "Red Banner group", "East Gate syndicate", "Harbor liaison"
    ]];
    if (_pool isEqualTo []) exitWith { "enemy network" };
    private _seed = [_taskId] call FADE_lore_hashStr;
    [_pool, _seed, 41] call FADE_lore_seededPick
};

// One codename per raid objective (uppercase op-name part B, e.g. HAMMER, TRIDENT) for map markers / tasks.
FADE_raid_pickObjectiveCodenames = {
    params ["_taskId", "_count"];
    _count = (round _count) max 1 min 10;
    private _pool = +(missionNamespace getVariable ["FADE_operationNamePartB", []]);
    if (_pool isEqualTo []) exitWith {
        private _fallback = [];
        for "_i" from 1 to _count do { _fallback pushBack format ["OBJ%1", _i] };
        _fallback
    };
    private _unique = [];
    {
        private _w = toUpper _x;
        if (_w != "" && { !(_w in _unique) }) then { _unique pushBack _w };
    } forEach _pool;
    if (_unique isEqualTo []) exitWith {
        private _fallback = [];
        for "_i" from 1 to _count do { _fallback pushBack format ["OBJ%1", _i] };
        _fallback
    };
    private _seed = [_taskId] call FADE_lore_hashStr;
    private _order = +_unique;
    for "_i" from (count _order - 1) to 1 step -1 do {
        private _j = [_seed, _i * 31, _i + 1] call FADE_lore_seededIndex;
        private _tmp = _order select _i;
        _order set [_i, _order select _j];
        _order set [_j, _tmp];
    };
    private _names = _order select [0, _count min count _order];
    while { count _names < _count } do {
        _names pushBack format ["OBJ%1", count _names + 1];
    };
    _names
};

FADE_raid_zoneDifficultyMul = {
    params ["_zoneIndex", "_friendlyPlayerCount"];
    // Zone/player boost only — FADE_scaleOpforCount applies FADE_opforPopulationScale once inside FADE_raid_applyScale.
    private _playerStep = missionNamespace getVariable ["FADE_raidPlayerDifficultyStep", 0.15];
    private _zoneStep = missionNamespace getVariable ["FADE_raidZoneDifficultyStep", 0.1];
    private _playerBoost = 1 + (_playerStep * ((_friendlyPlayerCount - 1) max 0));
    private _zoneBoost = 1 + (_zoneStep * (_zoneIndex max 0));
    ((_playerBoost * _zoneBoost) min 2.5) max 0.5
};

// SQF nested code cannot close over outer locals — pass _difficultyMul explicitly (not a returned lambda).
FADE_raid_applyScale = {
    params ["_baseCount", "_difficultyMul", ["_minCount", 1], ["_maxCount", -1]];
    private _baseFn = missionNamespace getVariable ["FADE_scaleOpforCount", { params ["_b"]; _b }];
    [_baseCount * _difficultyMul, _minCount, _maxCount] call _baseFn
};

FADE_raid_weightedPick = {
    params ["_pool", "_weights"];
    private _total = 0;
    { _total = _total + _x } forEach _weights;
    if (_total <= 0) exitWith { selectRandom _pool };
    private _roll = random _total;
    private _acc = 0;
    private _picked = _pool select 0;
    {
        _acc = _acc + (_weights select _forEachIndex);
        if (_roll < _acc) exitWith { _picked = _x };
    } forEach _pool;
    _picked
};

// Returns array of variant IDs length _count. Guarantees >=1 in-zone and >=1 RTB when _count >= 2;
// at most one RecoverHostage.
FADE_raid_pickVariants = {
    params ["_count"];
    _count = (round _count) max 1 min 5;
    private _inZone = [] call FADE_raid_inZoneVariants;
    private _rtb = [] call FADE_raid_rtbVariants;
    private _weightsMap = missionNamespace getVariable ["FADE_raidVariantWeights", createHashMapFromArray [
        ["RecoverObject", 1.2],
        ["KillHVT", 1.0],
        ["CaptureHVT", 0.9],
        ["RecoverHostage", 0.7]
    ]];
    private _out = [];
    if (_count >= 2) then {
        _out pushBack (selectRandom _inZone);
        _out pushBack (selectRandom _rtb);
    };
    while { count _out < _count } do {
        private _pool = _inZone + _rtb;
        private _hostageUsed = "RecoverHostage" in _out;
        if (_hostageUsed) then { _pool = _pool - ["RecoverHostage"] };
        private _wts = _pool apply { _weightsMap getOrDefault [_x, 1] };
        _out pushBack ([_pool, _wts] call FADE_raid_weightedPick);
    };
    _out = _out call BIS_fnc_arrayShuffle;
    if (_count >= 2) then {
        if ((_out findIf { _x in _inZone }) < 0) then { _out set [0, selectRandom _inZone] };
        if ((_out findIf { _x in _rtb }) < 0) then { _out set [1, selectRandom _rtb] };
        while { { _x == "RecoverHostage" } count _out > 1 } do {
            private _idx = _out find "RecoverHostage";
            if (_idx < 0) exitWith {};
            _out set [_idx, selectRandom _inZone];
        };
    };
    _out
};

// Fallback order when primary variant cannot spawn at a zone.
FADE_raid_variantFallbacks = {
    params ["_variant"];
    switch (_variant) do {
        case "RecoverHostage": { ["CaptureHVT", "KillHVT", "RecoverObject"] };
        case "CaptureHVT": { ["KillHVT", "RecoverObject"] };
        case "KillHVT": { ["RecoverHostage", "RecoverObject", "CaptureHVT"] };
        default { ["KillHVT", "RecoverObject"] };
    };
};

// Map picks: nearest unused civ zone per click; resolved zones must be >= _minSpacing apart.
FADE_raid_resolveMapZonePicks = {
    params ["_clicks", "_candidates", "_want", "_minSpacing"];
    if (!(_clicks isEqualType []) || { count _clicks < _want }) exitWith { [] };
    private _usedNames = [];
    private _picked = [];
    {
        private _click = _x;
        if (!([_click] call FADE_fnc_isValidMapClickPos)) exitWith {};
        private _bestIdx = -1;
        private _bestD = 1e15;
        {
            private _name = _x select 0;
            if (_name in _usedNames) then {} else {
                private _pos = _x select 1;
                private _d = _pos distance2D _click;
                if (_d < _bestD) then { _bestD = _d; _bestIdx = _forEachIndex };
            };
        } forEach _candidates;
        if (_bestIdx < 0) exitWith {};
        private _entry = _candidates select _bestIdx;
        private _pos = _entry select 1;
        private _ok = true;
        {
            if (((_x select 1) distance2D _pos) < _minSpacing) exitWith { _ok = false };
        } forEach _picked;
        if (!_ok) exitWith {};
        _usedNames pushBack (_entry select 0);
        _picked pushBack _entry;
    } forEach (_clicks select [0, _want]);
    if (count _picked < _want) then { [] } else { _picked }
};

// When primary zone center cannot host a variant, try another civ zone (spacing vs already-used zones).
FADE_raid_pickAlternateZoneCenter = {
    params ["_failedEntry", "_candidates", "_usedEntries", "_minSpacing"];
    if (!(_failedEntry isEqualType []) || { count _failedEntry < 2 }) exitWith { [] };
    private _usedNames = _usedEntries apply { _x select 0 };
    private _pool = +(_candidates select { !((_x select 0) in _usedNames) });
    _pool = _pool call BIS_fnc_arrayShuffle;
    private _picked = [];
    {
        private _pos = _x select 1;
        private _ok = true;
        {
            if ((_pos distance2D (_y select 1)) < _minSpacing) exitWith { _ok = false };
        } forEach _usedEntries;
        if (_ok) exitWith { _picked = _x };
    } forEach _pool;
    _picked
};

FADE_raid_trySpawnVariant = {
    params [
        "_variant",
        "_zoneCenter",
        "_sideEnemy",
        "_enemyUnits",
        "_diffMul",
        ["_childTaskId", ""],
        ["_missionTaskId", ""],
        ["_targetAssign", []]
    ];
    private _hvtCodename = "";
    private _hostageIdentity = "";
    if (_targetAssign isEqualType [] && { count _targetAssign >= 2 }) then {
        if (_targetAssign select 0 == "hvt") then { _hvtCodename = _targetAssign select 1 };
        if (_targetAssign select 0 == "hostage") then { _hostageIdentity = _targetAssign select 1 };
    };
    private _buildRadiusHvt = missionNamespace getVariable ["FADE_raidBuildSearchRadiusM", 450];
    private _buildRadiusObj = missionNamespace getVariable ["FADE_raidBuildSearchRadiusM", 450];
    private _buildRadiusHostage = missionNamespace getVariable ["FADE_raidBuildSearchRadiusM", 450];
    private _patrolRadius = missionNamespace getVariable ["FADE_raidPatrolRadiusM", 90];
    private _nearGarRadius = missionNamespace getVariable ["FADE_garrisonMissionNearbyRadiusM", 450];
    private _nearGarMax = missionNamespace getVariable ["FADE_raidNearbyGarrisonMaxPerZone", 4];
    private _innerGarExclude = missionNamespace getVariable ["FADE_raidTargetImmediateGarrisonRadiusM", 250];
    private _hvtMinSlots = 10;
    private _objMinSlots = 6;
    private _hostageMinSlots = 5;

    private _result = switch (_variant) do {
        case "RecoverObject": {
            [_zoneCenter, _buildRadiusObj, _objMinSlots, _sideEnemy, _enemyUnits, _diffMul, _patrolRadius] call FADE_objective_spawnRecoverObject
        };
        case "KillHVT": {
            [_zoneCenter, _buildRadiusHvt, _hvtMinSlots, _sideEnemy, _enemyUnits, _diffMul, _patrolRadius, _hvtCodename] call FADE_objective_spawnKillHVT
        };
        case "CaptureHVT": {
            // Same building garrison as KillHVT.
            [_zoneCenter, _buildRadiusHvt, _hvtMinSlots, _sideEnemy, _enemyUnits, _diffMul, _patrolRadius, _hvtCodename] call FADE_objective_spawnKillHVT
        };
        default {
            [_zoneCenter, _buildRadiusHostage, _hostageMinSlots, _sideEnemy, _enemyUnits, _diffMul, _patrolRadius, _hostageIdentity] call FADE_objective_spawnRecoverHostage
        };
    };
    _result params ["_ok", "_groups", "_objects", "_winPos", "_payload", ["_anchorBld", objNull]];
    if (_ok && { _variant == "RecoverObject" } && { count _objects > 0 } && { _childTaskId != "" }) then {
        [_objects select 0, _childTaskId] call FADE_objective_addRecoverHoldAction;
    };
    if (_ok && { _variant == "RecoverHostage" } && { _payload isEqualType [] } && { count _payload > 0 } && { !isNull (_payload select 0) } && { _childTaskId != "" }) then {
        [_payload select 0, _childTaskId] call FADE_objective_registerHostageFreeHold;
    };
    if (_ok && { _missionTaskId != "" }) then {
        private _targetBld = _anchorBld;
        if (isNull _targetBld) then {
            private _nearB = nearestObjects [_winPos, ["House", "Building"], 35];
            _targetBld = if (count _nearB > 0) then { _nearB select 0 } else { objNull };
        };
        [_winPos, if (isNull _targetBld) then { [] } else { [_targetBld] }, _sideEnemy, _enemyUnits, _diffMul, _groups] call FADE_objective_spawnImmediateAreaGarrison;
        if (!isNull _targetBld) then {
            private _vgBarrels = [];
            private _excl = if (!isNull _targetBld) then { [_targetBld] } else { [] };
            [
                _missionTaskId, _targetBld, _zoneCenter, _groups, _vgBarrels, _enemyUnits, _diffMul,
                _nearGarRadius, _nearGarMax, 1, _excl, _winPos, _innerGarExclude
            ] call FADE_objective_registerNearbyGarrisons;
            { _objects pushBack _x } forEach _vgBarrels;
        };
    };
    [_ok, _variant, _groups, _objects, _winPos, _payload]
};

FADE_raid_spawnZone = {
    params [
        "_primaryVariant",
        "_zoneCenter",
        "_sideEnemy",
        "_enemyUnits",
        "_diffMul",
        "_childTaskId",
        ["_missionTaskId", ""],
        ["_targetAssign", []]
    ];
    private _tryList = [_primaryVariant] + ([_primaryVariant] call FADE_raid_variantFallbacks);
    private _tryListUnique = [];
    { if (!(_x in _tryListUnique)) then { _tryListUnique pushBack _x } } forEach _tryList;
    private _baseRadius = missionNamespace getVariable ["FADE_raidBuildSearchRadiusM", 450];
    private _searchRadii = [
        _baseRadius,
        (_baseRadius + 150) min 900,
        (_baseRadius + 300) min 1100
    ];
    private _searchCenters = [+_zoneCenter];
    { _searchCenters pushBack ([_zoneCenter, _x, _forEachIndex * 90] call BIS_fnc_relPos) } forEach [120, 220, 340];
    private _finalVariant = "";
    private _groups = [];
    private _objects = [];
    private _winPos = [0, 0, 0];
    private _payload = [];
    private _prevRadius = missionNamespace getVariable ["FADE_raidBuildSearchRadiusM", _baseRadius];
    {
        if (_finalVariant != "") exitWith {};
        private _variant = _x;
        {
            if (_finalVariant != "") exitWith {};
            private _radius = _x;
            {
                if (_finalVariant != "") exitWith {};
                missionNamespace setVariable ["FADE_raidBuildSearchRadiusM", _radius];
                private _attempt = [_variant, _x, _sideEnemy, _enemyUnits, _diffMul, _childTaskId, _missionTaskId, _targetAssign] call FADE_raid_trySpawnVariant;
                _attempt params ["_ok", "_usedVariant", "_g", "_o", "_wp", "_pl"];
                if (_ok) exitWith {
                    _finalVariant = _usedVariant;
                    _groups = _g;
                    _objects = _o;
                    _winPos = _wp;
                    _payload = _pl;
                };
            } forEach _searchCenters;
        } forEach _searchRadii;
    } forEach _tryListUnique;
    missionNamespace setVariable ["FADE_raidBuildSearchRadiusM", _prevRadius];
    if (_finalVariant == "") exitWith {
        // #region agent log
        diag_log format [
            "[FAC DbgBrowser 62d308] H14 raidSpawnZone failed variant=%1 center=%2 radii=%3",
            _primaryVariant, _zoneCenter, _searchRadii
        ];
        // #endregion
        [false, "", [], [], [0, 0, 0], []]
    };
    // #region agent log
    if (_finalVariant != _primaryVariant) then {
        diag_log format [
            "[FAC DbgBrowser 62d308] H14 raidSpawnZone fallback primary=%1 used=%2 center=%3",
            _primaryVariant, _finalVariant, _zoneCenter
        ];
    };
    // #endregion
    [true, _finalVariant, _groups, _objects, _winPos, _payload]
};

// Approximate intel at zone centre; refines to precise objective on recon/contact.
FADE_raid_startIntelMonitor = {
    params [
        "_taskId",
        "_childTaskId",
        "_zoneMarkerName",
        "_zoneEllipseName",
        "_approxCenter",
        "_precisePos",
        "_detectRadius",
        "_approxRadius",
        "_refineRadius"
    ];
    [_taskId, _childTaskId, _zoneMarkerName, _zoneEllipseName, _approxCenter, _precisePos, _detectRadius, _approxRadius, _refineRadius] spawn {
        params [
            "_taskId", "_childTaskId", "_zoneMarkerName", "_zoneEllipseName", "_approxCenter", "_precisePos",
            "_detectRadius", "_approxRadius", "_refineRadius"
        ];
        private _taskDone = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
        private _refined = missionNamespace getVariable ["FADE_raidIntelRefined_" + _zoneMarkerName, false];
        private _poll = (missionNamespace getVariable ["FADE_raidIntelPollSec", 2]) max 1;
        waitUntil {
            sleep _poll;
            if (call _taskDone) exitWith { true };
            if (missionNamespace getVariable ["FADE_raidAborted_" + _taskId, false]) exitWith { true };
            if (_refined) exitWith { true };
            private _trigger = false;
            private _players = [] call FADE_getAlivePlayers;
            {
                if ((_x distance2D _approxCenter) < _detectRadius || { (_x distance2D _precisePos) < _detectRadius }) exitWith { _trigger = true };
            } forEach _players;
            if (!_trigger) then {
                private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
                private _nearEnemy = allUnits select {
                    side _x == _sideEnemy && { alive _x } && { (_x distance2D _precisePos) < _detectRadius }
                };
                {
                    if (behaviour _x == "COMBAT") exitWith { _trigger = true };
                } forEach _nearEnemy;
            };
            if (_trigger) then {
                _refined = true;
                missionNamespace setVariable ["FADE_raidIntelRefined_" + _zoneMarkerName, true];
                if (markerShape _zoneEllipseName != "") then {
                    [_zoneEllipseName, _precisePos, _refineRadius] call FADE_mission_setRadiusMarkerGeometry;
                };
                if (markerShape _zoneMarkerName != "") then {
                    _zoneMarkerName setMarkerPos _precisePos;
                    _zoneMarkerName setMarkerType "mil_objective";
                };
                if (_childTaskId != "" && { !isNil "BIS_fnc_taskSetDestination" } && { !((_childTaskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) }) then {
                    [_childTaskId, _precisePos] call BIS_fnc_taskSetDestination;
                };
            };
            _refined
        };
        missionNamespace setVariable ["FADE_raidIntelRefined_" + _zoneMarkerName, nil];
    };
};

FADE_raid_assignMarkersToFriendlies = {
    params ["_sideFriendly", "_markerName"];
    {
        if (isPlayer _x && { side group _x == _sideFriendly }) then {
            _x setVariable ["FADE_myMissionMarker", _markerName, true];
        };
    } forEach allPlayers;
};

missionNamespace setVariable ["FADE_raid_inZoneVariants", FADE_raid_inZoneVariants];
missionNamespace setVariable ["FADE_raid_rtbVariants", FADE_raid_rtbVariants];
missionNamespace setVariable ["FADE_raid_pickCellName", FADE_raid_pickCellName];
missionNamespace setVariable ["FADE_raid_resolveMapZonePicks", FADE_raid_resolveMapZonePicks];
missionNamespace setVariable ["FADE_raid_pickObjectiveCodenames", FADE_raid_pickObjectiveCodenames];
missionNamespace setVariable ["FADE_raid_zoneDifficultyMul", FADE_raid_zoneDifficultyMul];
missionNamespace setVariable ["FADE_raid_applyScale", FADE_raid_applyScale];
missionNamespace setVariable ["FADE_raid_pickVariants", FADE_raid_pickVariants];
missionNamespace setVariable ["FADE_raid_spawnZone", FADE_raid_spawnZone];
missionNamespace setVariable ["FADE_raid_startIntelMonitor", FADE_raid_startIntelMonitor];
missionNamespace setVariable ["FADE_raid_assignMarkersToFriendlies", FADE_raid_assignMarkersToFriendlies];
missionNamespace setVariable ["FADE_raid_variantLabels", FADE_raid_variantLabels];
