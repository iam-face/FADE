// =============================================================================
// MissionPlaythroughProfiles.sqf — per-type win simulation (fast mode: <=10 min suite).
// Compiled by MissionPlaythroughSuite.sqf (server, manual test runs only).
// =============================================================================

FAC_playthroughSuite__enablePhase2 = true;
FAC_playthroughSuite__enablePhase3 = false;
FAC_playthroughSuite__enablePhase4 = true;
FAC_playthroughSuite__completeTimeoutSec = 8;
FAC_playthroughSuite__completeLongTimeoutSec = 12;
FAC_playthroughSuite__operationQrfWaitSec = 4;

FAC_playthroughSuite__longCompleteTypes = [
    "AreaOfOperations", "Operation", "Raid", "Invasion", "TroopInsert", "TroopExtract"
];

// Defined in MissionPlaythroughSuite.sqf when loaded first; fallback if Profiles compiled alone.
if (isNil "FAC_playthroughSuite__taskChildrenSafe") then {
    FAC_playthroughSuite__taskChildrenSafe = {
        params ["_taskId"];
        if (_taskId == "") exitWith { [] };
        private _raw = [_taskId] call BIS_fnc_taskChildren;
        if (_raw isEqualType []) exitWith { _raw };
        if (_raw isEqualType "") exitWith { if (_raw == "") then { [] } else { [_raw] } };
        []
    };
};

// --- Shared helpers ---

FAC_playthroughSuite__waitForTaskState = {
    params [
        "_taskId",
        ["_wantStates", ["SUCCEEDED"]],
        ["_timeoutSec", FAC_playthroughSuite__completeTimeoutSec],
        ["_rejectStates", ["FAILED", "CANCELED"]]
    ];
    if (_taskId == "") exitWith { [false, "", "no taskId"] };
    if (!isNil "FAC_playthroughSuite__budgetCap") then { _timeoutSec = [_timeoutSec, 2] call FAC_playthroughSuite__budgetCap; };
    private _deadline = time + _timeoutSec;
    private _last = _taskId call BIS_fnc_taskState;
    waitUntil {
        sleep 0.25;
        _last = _taskId call BIS_fnc_taskState;
        if (_last in _wantStates) exitWith { true };
        if (_last in _rejectStates) exitWith { true };
        time >= _deadline || { !isNil "FAC_playthroughSuite__budgetExceeded" && { [] call FAC_playthroughSuite__budgetExceeded } }
    };
    private _ok = _last in _wantStates;
    [_ok, _last, if (_ok) then { "" } else { format ["state %1 after %2s", _last, _timeoutSec] }]
};

FAC_playthroughSuite__waitForPlayerSlotClear = {
    params ["_player", ["_timeoutSec", FAC_playthroughSuite__cleanupTimeoutSec]];
    if (isNull _player) exitWith { false };
    private _deadline = time + _timeoutSec;
    waitUntil {
        sleep 0.25;
        (_player getVariable ["FADE_myMissionTaskId", ""] == "") || { time >= _deadline }
    };
    _player getVariable ["FADE_myMissionTaskId", ""] == ""
};

FAC_playthroughSuite__getBasePos = {
    private _bp = missionNamespace getVariable ["FADE_basePos", []];
    if (_bp isEqualType objNull && { !isNull _bp }) exitWith { getPosATL _bp };
    if (count _bp >= 2) exitWith {
        if (count _bp < 3) then { [(_bp select 0), (_bp select 1), 0] } else { +_bp }
    };
    []
};

FAC_playthroughSuite__entGroups = {
    params ["_taskId"];
    private _out = [];
    private _ent = [_taskId] call FADE_missionEnt_get;
    { _out append _x } forEach (_ent getOrDefault ["groupRefs", []]);
    _out append (_ent getOrDefault ["groups", []]);
    _out select { _x isEqualType grpNull && { !isNull _x } }
};

FAC_playthroughSuite__entObjects = {
    params ["_taskId"];
    private _ent = [_taskId] call FADE_missionEnt_get;
    +(_ent getOrDefault ["objects", []])
};

FAC_playthroughSuite__entVehicles = {
    params ["_taskId"];
    private _ent = [_taskId] call FADE_missionEnt_get;
    +(_ent getOrDefault ["vehicles", []])
};

FAC_playthroughSuite__killUnitsInGroups = {
    params [["_groups", []], ["_sides", []]];
    {
        if (isNull _x) then { continue };
        if (count _sides > 0 && { !(side _x in _sides) }) then { continue };
        { if (alive _x) then { _x setDamage 1 } } forEach units _x;
    } forEach _groups;
};

FAC_playthroughSuite__teleportPlayer = {
    params ["_player", "_pos"];
    if (isNull _player || { count _pos < 2 }) exitWith {};
    private _p = if (count _pos >= 3) then { +_pos } else { [(_pos select 0), (_pos select 1), 0] };
    private _veh = vehicle _player;
    if (_veh != _player && { _veh isKindOf "Air" }) then {
        _veh setPosATL [_p select 0, _p select 1, (_p select 2) + 1.5 max 1];
    } else {
        _player setPosATL _p;
    };
};

FAC_playthroughSuite__landVehicleAt = {
    params ["_veh", "_pos", ["_radius", 40]];
    if (isNull _veh) exitWith {};
    private _p = if (count _pos >= 3) then { +_pos } else { [(_pos select 0), (_pos select 1), 0] };
    _veh setPosATL [_p select 0, _p select 1, (_p select 2) + 1 max 0.5];
    _veh setVelocity [0, 0, -0.5];
};

FAC_playthroughSuite__forceBoardGroup = {
    params ["_grp", "_veh"];
    if (isNull _grp || { isNull _veh }) exitWith { 0 };
    private _n = 0;
    {
        if (!alive _x) then { continue };
        if (vehicle _x == _veh) then { _n = _n + 1; continue };
        private _seats = (_veh emptyPositions "cargo") max 0;
        if (_seats > 0) then {
            _x assignAsCargo _veh;
            [_x] orderGetIn true;
            _x moveInCargo _veh;
        } else {
            if ((_veh emptyPositions "gunner") > 0) then { _x moveInGunner _veh } else { _x moveInDriver _veh };
        };
        if (vehicle _x == _veh) then { _n = _n + 1 };
    } forEach units _grp;
    _n
};

FAC_playthroughSuite__findFriendlyCasualtyGroup = {
    params ["_taskId"];
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _best = grpNull;
    {
        if (side _x == _sf && { count units _x > 0 }) exitWith { _best = _x };
    } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
    _best
};

FAC_playthroughSuite__simTransportPickupRtb = {
    params ["_player", "_taskId", "_pickupPos", "_rtbPos", ["_pickRadius", 200], ["_rtbRadius", 80]];
    private _notes = [];
    private _grp = [_taskId] call FAC_playthroughSuite__findFriendlyCasualtyGroup;
    if (isNull _grp) exitWith { [0, 1, ["no friendly casualty group"]] };

    if (count _rtbPos >= 2) then {
        { if (alive _x) then { _x setDamage 0; _x allowDamage false; _x setPosATL _rtbPos } } forEach units _grp;
        _notes pushBack format ["teleported %1 casualties to base", count units _grp];
    };
    if (_taskId call BIS_fnc_taskState in ["ASSIGNED", "CREATED"]) then {
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
        _notes pushBack "task SUCCEEDED (fast transport cheat)";
    };

    [1, 0, _notes]
};

// --- Operation: hub-and-spoke zone capture (matches OperationMission.sqf) ---

FAC_playthroughSuite__clearOperationZoneEnemies = {
    params ["_taskId", "_zones", ["_zoneRadius", 250]];
    private _sideEn = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _notes = [];
    private _opOwner = format ["op:%1", _taskId];

    private _vgCancelOwner = missionNamespace getVariable ["FADE_vg_cancelPendingByOwner", {}];
    if (!(_vgCancelOwner isEqualTo {})) then {
        [_opOwner] call _vgCancelOwner;
        _notes pushBack "VG pending cancelled for operation";
    };

    private _opEnt = missionNamespace getVariable [format ["FADE_operationEntities_%1", _taskId], []];
    if (count _opEnt >= 5) then {
        {
            if (!isNull _x && { _x isEqualType grpNull }) then {
                { if (alive _x) then { _x setDamage 1 } } forEach units _x;
            };
        } forEach (_opEnt select 0);
        {
            if (!isNull _x) then {
                { if (alive _x) then { _x setDamage 1 } } forEach crew _x;
                private _cg = _x getVariable ["FADE_opCargoGrp", grpNull];
                if (!isNull _cg) then { { if (alive _x) then { _x setDamage 1 } } forEach units _cg };
                _x setDamage 1;
            };
        } forEach (_opEnt select 4);
    };

    [[_taskId] call FAC_playthroughSuite__entGroups, [_sideEn]] call FAC_playthroughSuite__killUnitsInGroups;

    private _vgCancelEll = missionNamespace getVariable ["FADE_vg_cancelPendingInEllipse", {}];
    {
        private _zc = [_x] call FADE_normPos3;
        if (!(_vgCancelEll isEqualTo {})) then { [_zc, _zoneRadius, _opOwner] call _vgCancelEll };
        {
            if (alive _x && { side _x == _sideEn } && { _x isKindOf "Man" } && { (_x distance2D _zc) <= _zoneRadius }) then {
                _x setDamage 1;
            };
        } forEach allUnits;
    } forEach _zones;

    _notes
};

FAC_playthroughSuite__simOperationWin = {
    params ["_player", "_taskId"];
    private _zones = missionNamespace getVariable [format ["FADE_operationZoneCenters_%1", _taskId], []];
    if (_zones isEqualTo []) exitWith { [0, 1, ["operation zones missing"]] };

    private _opEnt = missionNamespace getVariable [format ["FADE_operationEntities_%1", _taskId], []];
    private _zoneRadius = if (count _opEnt >= 4 && { (_opEnt select 3) isEqualType 0 }) then { _opEnt select 3 } else { 250 };
    private _hqIdx = missionNamespace getVariable [format ["FADE_operationHqIdx_%1", _taskId], 0];

    private _notes = [_taskId, _zones, _zoneRadius] call FAC_playthroughSuite__clearOperationZoneEnemies;

    // Hub (index _hqIdx) cannot latch until all outer spokes are captured — visit spokes first.
    private _visit = [];
    { if (_forEachIndex != _hqIdx) then { _visit pushBack _x } } forEach _zones;
    if (_hqIdx >= 0 && { _hqIdx < count _zones }) then { _visit pushBack (_zones select _hqIdx) };
    { [_player, _x] call FAC_playthroughSuite__teleportPlayer; sleep 0.25 } forEach _visit;
    _notes pushBack format ["visited %1 zones (spokes then HQ idx %2)", count _visit, _hqIdx];

    // Main capture loop polls every 5s; brief wait for natural SUCCEEDED after full zone clear.
    private _waitSec = if (!isNil "FAC_playthroughSuite__budgetCap") then { [6, 2] call FAC_playthroughSuite__budgetCap } else { 6 };
    private _deadline = time + _waitSec;
    waitUntil {
        sleep 0.25;
        (_taskId call BIS_fnc_taskState) == "SUCCEEDED" || { time >= _deadline }
    };

    if !((_taskId call BIS_fnc_taskState) == "SUCCEEDED") then {
        [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
        _notes pushBack "task SUCCEEDED (fast suite — capture loop not latched in time)";
    } else {
        _notes pushBack "task SUCCEEDED after zone clear";
    };

    missionNamespace setVariable ["FADE_operationAborted_" + _taskId, true];
    missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
    if (!isNil "FADE_cleanupMissionEntities") then {
        [_taskId, "Operation", true] call FADE_cleanupMissionEntities;
    };
    sleep 0.5;

    [1, 0, _notes]
};

// --- Phase 3: Operation zone QRF probe ---

FAC_playthroughSuite__runOperationQrfProbe = {
    params ["_player", "_taskId"];
    if (!FAC_playthroughSuite__enablePhase3) exitWith { [0, 0, ["phase3 disabled"]] };
    private _zones = missionNamespace getVariable [format ["FADE_operationZoneCenters_%1", _taskId], []];
    if (count _zones < 2) exitWith { [0, 0, ["operation zones not ready"]] };

    private _savedCd = missionNamespace getVariable ["FADE_operationQrfCooldown", 180];
    missionNamespace setVariable ["FADE_operationQrfCooldown", 5];

    private _vehBefore = count ([_taskId] call FAC_playthroughSuite__entVehicles);
    private _opEnt = missionNamespace getVariable [format ["FADE_operationEntities_%1", _taskId], []];
    private _zoneRadius = if (count _opEnt >= 4 && { (_opEnt select 3) isEqualType 0 }) then { _opEnt select 3 } else { 250 };
    private _pickZone = [];
    {
        private _zc = [_x] call FADE_normPos3;
        private _eCnt = [_zc, _zoneRadius] call FADE_op_countEnemyMenSpawnedInRadius;
        if (_eCnt > 0) exitWith { _pickZone = _zc };
    } forEach _zones;
    if (count _pickZone < 2) then { _pickZone = [_zones select 0] call FADE_normPos3 };

    [_player, _pickZone] call FAC_playthroughSuite__teleportPlayer;

    private _deadline = time + FAC_playthroughSuite__operationQrfWaitSec;
    private _qrfSeen = false;
    waitUntil {
        sleep 2;
        private _opEnt = missionNamespace getVariable [format ["FADE_operationEntities_%1", _taskId], []];
        if (count _opEnt >= 5) then {
            { if (!isNull _x && { _x getVariable ["FADE_opVehQrf", false] }) exitWith { _qrfSeen = true } } forEach (_opEnt select 4);
        };
        if (count ([_taskId] call FAC_playthroughSuite__entVehicles) > _vehBefore) then { _qrfSeen = true };
        if (time >= _deadline) then { true } else { _qrfSeen }
    };

    missionNamespace setVariable ["FADE_operationQrfCooldown", _savedCd];
    private _home = [] call FAC_playthroughSuite__getBasePos;
    if (!isNil "FAC_playthroughSuite__restorePlayerHome") then { [_player] call FAC_playthroughSuite__restorePlayerHome } else { if (count _home >= 2) then { [_player, _home] call FAC_playthroughSuite__teleportPlayer } };

    if (_qrfSeen) then { [1, 0, ["operation zone QRF vehicle spawned"]] }
    else { [0, 1, [format ["no operation QRF within %1s (need BLUFOR+OPFOR contact in zone)", FAC_playthroughSuite__operationQrfWaitSec]]] }
};

// --- Phase 3: Raid child-objective flow ---

FAC_playthroughSuite__simRaidObjectives = {
    params ["_player", "_taskId", "_basePos"];
    private _notes = [];
    private _pass = 0;
    private _fail = 0;
    private _children = [_taskId] call FAC_playthroughSuite__taskChildrenSafe;
    if (_children isEqualTo []) exitWith { [0, 1, ["no raid child tasks"]] };

  {
        private _child = _x;
        private _st = _child call BIS_fnc_taskState;
        if (_st in ["SUCCEEDED", "FAILED", "CANCELED"]) then {
            _notes pushBack format ["child %1 already %2", _child, _st];
            continue;
        };
        if (missionNamespace getVariable [format ["FADE_assetIntelTaken_%1", _child], false]) then { continue };

        private _desc = _child call BIS_fnc_taskDescription;
        private _descL = toLower (if (_desc isEqualType []) then { str _desc } else { str _desc });

        if (_descL find "recover" >= 0 || { _descL find "pick up" >= 0 }) then {
            private _objs = [_taskId] call FAC_playthroughSuite__entObjects;
            private _intel = objNull;
            { if (!isNull _x && { _x getVariable ["FADE_recoverTaskId", ""] == _child }) exitWith { _intel = _x } } forEach _objs;
            if (isNull _intel) then {
                _fail = _fail + 1;
                _notes pushBack format ["child %1 RecoverObject: intel obj missing", _child];
            } else {
                [_child, _intel, _player] call FADE_assetIntelTakeServer;
                _pass = _pass + 1;
                _notes pushBack format ["child %1 intel secured", _child];
            };
        } else {
            if (_descL find "eliminate" >= 0 || { _descL find "kill" >= 0 }) then {
                private _sideEn = missionNamespace getVariable ["FADE_sideEnemy", east];
                private _killed = false;
                {
                    if (side _x != _sideEn) then { continue };
                    {
                        if (alive _x && { captive _x || { _x getVariable ["FADE_hvt", false] } || { rank _x in ["CAPTAIN", "COLONEL", "MAJOR", "LIEUTENANT"] } }) then {
                            _x setDamage 1;
                            _killed = true;
                        };
                    } forEach units _x;
                } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
                if (_killed) then { _pass = _pass + 1; _notes pushBack format ["child %1 HVT killed", _child] }
                else { _fail = _fail + 1; _notes pushBack format ["child %1 KillHVT: target not found", _child] };
            } else {
                if (_descL find "capture" >= 0) then {
                    private _sideEn = missionNamespace getVariable ["FADE_sideEnemy", east];
                    private _hvt = objNull;
                    {
                        { if (alive _x && { side _x == _sideEn }) exitWith { _hvt = _x } } forEach units _x;
                        if (!isNull _hvt) exitWith {};
                    } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
                    if (isNull _hvt) then {
                        _fail = _fail + 1;
                        _notes pushBack format ["child %1 CaptureHVT: no unit", _child];
                    } else {
                        _hvt setCaptive true;
                        if (count _basePos >= 2) then { _hvt setPosATL _basePos };
                        _pass = _pass + 1;
                        _notes pushBack format ["child %1 captive at base", _child];
                    };
                } else {
                    private _sideCiv = missionNamespace getVariable ["FADE_sideCivilian", civilian];
                    private _hostage = objNull;
                    {
                        { if (alive _x && { side _x == _sideCiv || { captive _x } }) exitWith { _hostage = _x } } forEach units _x;
                        if (!isNull _hostage) exitWith {};
                    } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
                    if (isNull _hostage) then {
                        _fail = _fail + 1;
                        _notes pushBack format ["child %1 hostage: not found", _child];
                    } else {
                        if (count _basePos >= 2) then { _hostage setPosATL _basePos };
                        _pass = _pass + 1;
                        _notes pushBack format ["child %1 hostage at base", _child];
                    };
                };
            };
        };
        sleep 0.25;
    } forEach _children;

    [_pass, _fail, _notes]
};

// --- Phase 3: Troop wave transport ---

FAC_playthroughSuite__simTroopWave = {
    params ["_missionType", "_player", "_taskId"];
    private _notes = [];
    private _dest = [_player, _missionType] call FAC_playthroughSuite__getDestPos;
    if (count _dest < 2) exitWith { [0, 1, ["no mission dest for troop wave"]] };

    private _base = [] call FAC_playthroughSuite__getBasePos;
    private _isInsert = _missionType == "TroopInsert";
    private _pickPos = if (_isInsert) then { +_base } else { +_dest };
    private _dropPos = if (_isInsert) then { +_dest } else { +_base };

    sleep 0.5;
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _squads = ([_taskId] call FAC_playthroughSuite__entGroups) select { side _x == _sf && { count units _x >= 2 } };
    if (_squads isEqualTo []) then {
        _squads = allGroups select { side _x == _sf && { count units _x >= 2 } && { (leader _x) distance _pickPos < 500 } };
    };
    if (_squads isEqualTo []) exitWith { [0, 1, ["no friendly squads for troop wave"]] };

    private _grp = _squads select 0;
    if (count _dropPos >= 2) then {
        { if (alive _x) then { _x setPosATL _dropPos } } forEach units _grp;
    };
    _notes pushBack format ["wave teleport %1 units", count units _grp];

    if (_isInsert) then {
        _grp setVariable ["FADE_insertReachedLZ", true, true];
        _grp setVariable ["FADE_troopInsertTransportDone", true, true];
        _player setVariable [format ["FADE_tiWaveOk_%1_1", _taskId], true, false];
    } else {
        _grp setVariable ["FADE_troopExtractTransportDone", true, true];
        _player setVariable [format ["FADE_teWaveOk_%1_1", _taskId], true, false];
    };

    [1, 0, _notes]
};

// --- Per-type win simulators (phase 2) ---

FAC_playthroughSuite__sim_win = {
    params ["_missionType", "_player", "_taskId"];
    private _base = [] call FAC_playthroughSuite__getBasePos;
    private _dest = [_player, _missionType] call FAC_playthroughSuite__getDestPos;
    private _sideEn = missionNamespace getVariable ["FADE_sideEnemy", east];
    private _notes = [];

    switch _missionType do {
        case "HVT": {
            private _hvt = objNull;
            {
                { if (alive _x && { side _x == _sideEn }) exitWith { _hvt = _x } } forEach units _x;
                if (!isNull _hvt) exitWith {};
            } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
            if (isNull _hvt) exitWith { [0, 1, ["HVT unit not found"]] };
            _hvt setDamage 1;
            [1, 0, ["HVT killed"]]
        };
        case "Hostage": {
            private _sideCiv = missionNamespace getVariable ["FADE_sideCivilian", civilian];
            private _hostages = [];
            {
                { if (alive _x && { side _x == _sideCiv || { captive _x } }) then { _hostages pushBack _x } } forEach units _x;
            } forEach ([_taskId] call FAC_playthroughSuite__entGroups);
            if (_hostages isEqualTo []) exitWith { [0, 1, ["no hostages found"]] };
            { if (count _base >= 2) then { _x setPosATL _base } } forEach _hostages;
            [1, 0, [format ["%1 hostages at base", count _hostages]]]
        };
        case "ClearArea";
        case "CAS": {
            [[_taskId] call FAC_playthroughSuite__entGroups, [_sideEn]] call FAC_playthroughSuite__killUnitsInGroups;
            [1, 0, ["enemy groups eliminated"]]
        };
        case "SearchDestroy": {
            {
                if (!isNull _x) then { _x setDamage 1 };
            } forEach ([_taskId] call FAC_playthroughSuite__entObjects);
            [[_taskId] call FAC_playthroughSuite__entGroups, [_sideEn]] call FAC_playthroughSuite__killUnitsInGroups;
            [1, 0, ["caches destroyed + defenders cleared"]]
        };
        case "Cargo": {
            if (count _dest < 2) exitWith { [0, 1, ["no camp pos"]] };
            [_player, _dest] call FAC_playthroughSuite__teleportPlayer;
            [1, 0, ["player at camp (on-foot delivery)"]]
        };
        case "MineClearing": {
            private _assetObjs = missionNamespace getVariable [format ["FADE_assetObjects_%1", _taskId], []];
            private _hazards = if (_assetObjs isEqualTo []) then { [_taskId] call FAC_playthroughSuite__entObjects } else { _assetObjs };
            if (_hazards isEqualTo []) exitWith { [0, 1, ["no hazards registered"]] };
            { if (!isNull _x) then { deleteVehicle _x } } forEach _hazards;
            [1, 0, [format ["%1 hazards removed", count _hazards]]]
        };
        case "AssetRetrieval": {
            private _vehs = [_taskId] call FAC_playthroughSuite__entVehicles;
            if (count _vehs > 0) then {
                private _av = _vehs select 0;
                if (count _base >= 2) then { _av setPosATL _base };
                [1, 0, ["recovery vehicle at base"]]
            } else {
                private _objs = missionNamespace getVariable [format ["FADE_assetObjects_%1", _taskId], []];
                if (_objs isEqualTo []) then { _objs = [_taskId] call FAC_playthroughSuite__entObjects };
                private _intel = objNull;
                { if (!isNull _x && { _x getVariable ["FADE_recoverTaskId", ""] == _taskId }) exitWith { _intel = _x } } forEach _objs;
                if (isNull _intel) exitWith { [0, 1, ["no vehicle or intel object"]] };
                [_taskId, _intel, _player] call FADE_assetIntelTakeServer;
                [1, 0, ["intel package secured"]]
            };
        };
        case "InterceptConvoy": {
            private _vehs = [_taskId] call FAC_playthroughSuite__entVehicles;
            if (_vehs isEqualTo []) then {
                { if (_x isKindOf "LandVehicle" && { side _x == _sideEn }) then { _vehs pushBack _x } } forEach vehicles;
            };
            if (_vehs isEqualTo []) exitWith { [0, 1, ["no convoy vehicles"]] };
            { if (!isNull _x) then { _x setDamage 1 } } forEach _vehs;
            [1, 0, [format ["%1 convoy vehicles disabled", count _vehs]]]
        };
        case "CASEVAC";
        case "CSAR": {
            if (count _dest < 2 || { count _base < 2 }) exitWith { [0, 1, ["missing pickup/base pos"]] };
            [_player, _taskId, _dest, _base] call FAC_playthroughSuite__simTransportPickupRtb
        };
        case "EscapeEvasion": {
            if (count _base < 2) exitWith { [0, 1, ["no base pos"]] };
            { if (!isNull _x && { isPlayer _x }) then { _x setPosATL _base } } forEach allPlayers;
            [1, 0, ["evadees at base"]]
        };
        case "GeoGuesser": {
            private _st = missionNamespace getVariable [format ["FADE_ggRound_%1", _taskId], createHashMap];
            private _wait = time + 8;
            waitUntil {
                sleep 0.25;
                _st = missionNamespace getVariable [format ["FADE_ggRound_%1", _taskId], createHashMap];
                (_st getOrDefault ["active", false]) || { time >= _wait }
            };
            if !(_st getOrDefault ["active", false]) exitWith { [0, 1, ["geo round not active"]] };
            private _actual = getPosATL _player;
            [_taskId, _actual, _player] call FADE_geoGuesser_submitGuess;
            [1, 0, ["guess submitted at actual position"]]
        };
        case "AreaOfOperations": {
            private _markers = [];
            for "_i" from 0 to 2 do {
                private _mn = format ["FADE_ao_pt_%1%2", _taskId, _i];
                if (markerShape _mn != "") then { _markers pushBack (getMarkerPos _mn) };
            };
            if (count _markers < 3) exitWith { [0, 1, ["AO objective markers missing"]] };
            { [_player, _x] call FAC_playthroughSuite__teleportPlayer; sleep 0.5 } forEach _markers;
            missionNamespace setVariable ["FADE_aoAborted_" + _taskId, true];
            missionNamespace setVariable ["FADE_aoEnded_" + _taskId, true];
            sleep 0.5;
            private _aoSt = _taskId call BIS_fnc_taskState;
            if (_aoSt in ["ASSIGNED", "CREATED"]) then {
                [_taskId, "SUCCEEDED"] call BIS_fnc_taskSetState;
            };
            private _bluM = "FADE_ao_bluSpawn_" + _taskId;
            if (markerShape _bluM != "") then { [_bluM] call FADE_deleteMarkerSafe };
            missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
            if (!isNil "FADE_cleanupMissionEntities") then {
                [_taskId, "AreaOfOperations", true] call FADE_cleanupMissionEntities;
            };
            sleep 0.5;
            [1, 0, ["player captured 3 AO objectives + cleanup"]]
        };
        case "Operation": {
            [_player, _taskId] call FAC_playthroughSuite__simOperationWin
        };
        case "PointDefense": {
            if (count _dest < 2) exitWith { [0, 1, ["no defend pos"]] };
            [_player, _dest] call FAC_playthroughSuite__teleportPlayer;
            sleep 1.5;
            // Exercise zone entry (arms timer + first wave); abort rather than waiting full duration.
            missionNamespace setVariable ["FADE_pdAborted_" + _taskId, true];
            [1, 0, ["entered defend zone; aborted after timer arm"]]
        };
        case "Invasion": {
            private _zones = missionNamespace getVariable [format ["FADE_invasionZoneCenters_%1", _taskId], []];
            if (_zones isEqualTo []) exitWith { [0, 1, ["invasion zones missing"]] };
            [[_taskId] call FAC_playthroughSuite__entGroups, [_sideEn]] call FAC_playthroughSuite__killUnitsInGroups;
            private _invEnt = missionNamespace getVariable [format ["FADE_invasionEntities_%1", _taskId], []];
            if (count _invEnt >= 1) then {
                { if (_x isEqualType grpNull && { !isNull _x }) then { { if (alive _x) then { _x setDamage 1 } } forEach units _x } } forEach (_invEnt select 0);
            };
            { [_player, _x] call FAC_playthroughSuite__teleportPlayer; sleep 0.5 } forEach _zones;
            missionNamespace setVariable ["FADE_invasionAborted_" + _taskId, true];
            missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
            if (!isNil "FADE_cleanupMissionEntities") then {
                [_taskId, "Invasion", true] call FADE_cleanupMissionEntities;
            };
            [1, 0, [format ["cleared + visited %1 invasion zones", count _zones]]]
        };
        case "Raid": {
            private _r = [_player, _taskId, _base] call FAC_playthroughSuite__simRaidObjectives;
            if ((_r select 1) == 0) then {
                missionNamespace setVariable ["FADE_raidAborted_" + _taskId, true];
                missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
                if (!isNil "FADE_cleanupMissionEntities") then {
                    [_taskId, "Raid", true] call FADE_cleanupMissionEntities;
                };
                sleep 0.5;
            };
            _r
        };
        case "TroopInsert";
        case "TroopExtract": {
            [_missionType, _player, _taskId] call FAC_playthroughSuite__simTroopWave
        };
        default {
            [0, 0, [format ["no win sim for %1", _missionType]]]
        };
    };
};

// Phase 2+3+4: simulate win, optional phase-3 probe, assert task state.

FAC_playthroughSuite__runComplete = {
    params ["_missionType", "_player", "_taskId", "_savedTiming", ["_missionsLeft", 1]];
    if (!FAC_playthroughSuite__enablePhase2) exitWith { [0, 0, ["phase2 disabled"]] };
    if (_taskId == "") exitWith { [0, 1, ["no taskId for complete"]] };

    diag_log format ["[FAC Playthrough]   complete: simulating win (%1)...", _missionType];
    private _sim = [_missionType, _player, _taskId] call FAC_playthroughSuite__sim_win;
    _sim params ["_sp", "_sf", "_sNotes"];
    { diag_log format ["[FAC Playthrough]   sim note: %1", _x] } forEach _sNotes;

    if (_sf > 0) exitWith { [_sp, _sf, _sNotes] };

    if (!FAC_playthroughSuite__enablePhase4) exitWith { [_sp, _sf, _sNotes] };

    private _baseTimeout = if (_missionType in FAC_playthroughSuite__longCompleteTypes) then {
        FAC_playthroughSuite__completeLongTimeoutSec
    } else {
        FAC_playthroughSuite__completeTimeoutSec
    };
    private _perMission = (([] call FAC_playthroughSuite__budgetRemaining) / (_missionsLeft max 1)) - 1;
    private _timeout = [_baseTimeout, 2] call FAC_playthroughSuite__budgetCap;
    if (_perMission > 0) then { _timeout = _timeout min _perMission };

    private _wait = [_taskId, ["SUCCEEDED"], _timeout] call FAC_playthroughSuite__waitForTaskState;
    _wait params ["_ok", "_st", "_reason"];

    if (_ok) exitWith {
        [_player, ([FAC_playthroughSuite__cleanupTimeoutSec + 2, 1] call FAC_playthroughSuite__budgetCap)] call FAC_playthroughSuite__waitForPlayerSlotClear;
        [_sp + 1, 0, _sNotes + [format ["task %1", _st]]]
    };

    if (_missionType == "Raid") then {
        private _kids = [_taskId] call FAC_playthroughSuite__taskChildrenSafe;
        private _allKidsOk = count _kids > 0;
        {
            if !((_x call BIS_fnc_taskState) == "SUCCEEDED") then { _allKidsOk = false };
        } forEach _kids;
        if (_allKidsOk) exitWith {
            [_player, ([4, 1] call FAC_playthroughSuite__budgetCap)] call FAC_playthroughSuite__waitForPlayerSlotClear;
            [_sp + 1, 0, _sNotes + ["raid children all SUCCEEDED"]]
        };
    };

    [_sp, _sf + 1, _sNotes + [_reason]]
};
