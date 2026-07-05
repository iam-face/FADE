// =============================================================================
// MissionRaid.sqf  -  Global multi-objective raid. N objectives at separate
// CIV_T_* zones. Each zone: weighted variant (in-zone + RTB mix), per-zone
// QRF on player detection, intel refines on recon/contact. Helpers in
// FADE_ObjectiveHelpers.sqf and FADE_RaidHelpers.sqf.
// =============================================================================
if (!isServer) exitWith {};
FADE_runMission_Raid = {
    private _missionType = missionNamespace getVariable ["FADE_missionRun_missionType", ""];
    private _destPos = missionNamespace getVariable ["FADE_missionRun_destPos", [0,0,0]];
    private _player = missionNamespace getVariable ["FADE_missionRun_player", objNull];
    private _fromMapClick = missionNamespace getVariable ["FADE_missionRun_fromMapClick", false];
    private _mapAnchor = missionNamespace getVariable ["FADE_missionRun_mapAnchor", []];
    private _raidZoneClicks = missionNamespace getVariable ["FADE_missionRun_raidZoneClicks", []];
    private _enemyUnits = missionNamespace getVariable ["FADE_missionRun_enemyUnits", []];
    private _sideFriendly = missionNamespace getVariable ["FADE_missionRun_sideFriendly", west];
    private _sideEnemy = missionNamespace getVariable ["FADE_missionRun_sideEnemy", east];
    private _markerEnemy = missionNamespace getVariable ["FADE_missionRun_markerEnemy", "ColorEAST"];
    private _taskId = missionNamespace getVariable ["FADE_missionRun_taskId", ""];
    private _operationNameUpper = missionNamespace getVariable ["FADE_missionRun_operationNameUpper", ""];
    private _briefGuiTail = missionNamespace getVariable ["FADE_missionRun_briefGuiTail", ""];
    private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", {}];
    private _enemyFactionName = missionNamespace getVariable ["FADE_missionRun_enemyFactionName", ""];
    private _basePos = missionNamespace getVariable ["FADE_missionRun_basePos", [0,0,0]];
    private _scaleOpforCount = missionNamespace getVariable ["FADE_scaleOpforCount", {}];
    private _fnc_createMissionTask = missionNamespace getVariable ["FADE_mission_createTask", {}];
    private _friendlyPlayerCount = missionNamespace getVariable ["FADE_missionRun_friendlyPlayerCount", 0];
    private _friendlyFactionName = missionNamespace getVariable ["FADE_missionRun_friendlyFactionName", ""];
    private _estimatedOpforCount = missionNamespace getVariable ["FADE_missionRun_estimatedOpforCount", 0];
    private _opforCountFactor = missionNamespace getVariable ["FADE_missionRun_opforCountFactor", 1];
    private _intelFormatter = missionNamespace getVariable ["FADE_formatSituationIntelHtml", {}];
    private _loreShort = missionNamespace getVariable ["FADE_missionRun_loreShort", ""];
    private _loreLong = missionNamespace getVariable ["FADE_missionRun_loreLong", ""];
    private _loreSmeacHtml = missionNamespace getVariable ["FADE_missionRun_loreSmeacHtml", ""];

    private _raidZoneCount = (round (missionNamespace getVariable ["FADE_raidObjectiveCount", 3])) max 2 min 5;
    private _minDistBase = 1000;
    private _minDistBetweenZones = missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000];
    private _raidQrfSkipDetection = missionNamespace getVariable ["FADE_raidQrfSkipDetectionWait", false];
    private _raidQrfFirstMin = missionNamespace getVariable ["FADE_raidQrfFirstDelayMin", 0];
    private _raidQrfFirstMax = missionNamespace getVariable ["FADE_raidQrfFirstDelayMax", 30];
    private _raidTimeoutSec = missionNamespace getVariable ["FADE_raidTimeoutSec", 0];
    private _baseDistForComplete = 100;
    private _zoneDetectRadius = missionNamespace getVariable ["FADE_raidZoneDetectRadiusM", 300];
    private _intelApproxRadius = missionNamespace getVariable ["FADE_missionApproxZoneRadiusM", 110];
    private _intelRefineRadius = missionNamespace getVariable ["FADE_raidIntelRefineRadiusM", 300];
    private _variantLabels = missionNamespace getVariable ["FADE_raid_variantLabels", createHashMap];

    [] call FADE_ensureBisTaskSetParent;

    private _enemyUnitsRaid = +_enemyUnits;
    _enemyUnitsRaid = [_enemyUnitsRaid] call (missionNamespace getVariable ["FADE_filterEnemyUnitsArmed", { _this select 0 }]);
    if (count _enemyUnitsRaid == 0) then { _enemyUnitsRaid = +_enemyUnits };
    if (count _enemyUnitsRaid == 0) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", "No enemy units configured."] call FADE_missionErrorHint;
    };

    private _cellName = [_taskId] call FADE_raid_pickCellName;
    private _zoneCodenames = [_taskId, _raidZoneCount] call FADE_raid_pickObjectiveCodenames;

    // ---- Zone pick ----
    private _civNames = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _candidates = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            if (count _p >= 2 && { (_p distance _basePos) >= _minDistBase }) then {
                _candidates pushBack [_x, [(_p select 0), (_p select 1), (_p param [2, 0])]];
            };
        };
    } forEach _civNames;

    if (count _candidates < _raidZoneCount) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", format ["Not enough civ zones (need %1) at least 1 km from base.", _raidZoneCount]] call FADE_missionErrorHint;
    };

    private _useRaidMapPicks = _fromMapClick && { _raidZoneClicks isEqualType [] } && { count _raidZoneClicks >= _raidZoneCount };
    private _zonesPicked = [];
    if (_useRaidMapPicks) then {
        _zonesPicked = [_raidZoneClicks, _candidates, _raidZoneCount, _minDistBetweenZones] call FADE_raid_resolveMapZonePicks;
        if (count _zonesPicked < _raidZoneCount) exitWith {
            [_player] call FADE_clearActiveMission;
            [_player, "MISSION ERROR", format [
                "Could not place %1 distinct civ zones from your map picks (zones must be %2 m apart and snap to different settlements). Try again.",
                _raidZoneCount,
                _minDistBetweenZones
            ]] call FADE_missionErrorHint;
        };
    } else {
    private _useMapAnchor = _fromMapClick && { [_mapAnchor] call FADE_fnc_isValidMapClickPos };
    if (_useMapAnchor) then {
        _candidates = [_candidates, [], { (_x select 1) distance2D _mapAnchor }, "ASCEND"] call BIS_fnc_sortBy;
    } else {
        _candidates = _candidates call BIS_fnc_arrayShuffle;
    };

    private _fnc_pickZonesWithSpacing = {
        params ["_cands", "_want", "_minSpacing"];
        private _picked = [];
        {
            if (count _picked >= _want) exitWith {};
            private _pos = _x select 1;
            private _ok = true;
            { if ((_pos distance2D (_x select 1)) < _minSpacing) exitWith { _ok = false } } forEach _picked;
            if (_ok) then { _picked pushBack _x };
        } forEach _cands;
        _picked
    };

    _zonesPicked = [_candidates, _raidZoneCount, _minDistBetweenZones] call _fnc_pickZonesWithSpacing;
    if (count _zonesPicked < _raidZoneCount) then {
        _zonesPicked = [_candidates, _raidZoneCount, _minDistBetweenZones * 0.5] call _fnc_pickZonesWithSpacing;
    };
    if (count _zonesPicked < _raidZoneCount) then {
        _zonesPicked = _candidates select [0, _raidZoneCount min count _candidates];
    };
    if (count _zonesPicked < _raidZoneCount) exitWith {
        [_player] call FADE_clearActiveMission;
        [_player, "MISSION ERROR", format ["Could not find %1 distinct civ zones for the raid.", _raidZoneCount]] call FADE_missionErrorHint;
    };
    };

    private _zoneVariantsPlanned = [_raidZoneCount] call FADE_raid_pickVariants;

    private _fnc_createChildTask = {
        params ["_childId", "_desc", "_title", "_pos", "_taskType"];
        [_sideFriendly, [_childId, _taskId], [_desc, _title, ""], _pos, "CREATED", 1, true, _taskType, true] call BIS_fnc_taskCreate;
    };

    // ---- Pass 1: summary for parent task ----
    private _pickHvtFn = missionNamespace getVariable ["FADE_pickHvtCodename", {}];
    private _pickHostageFn = missionNamespace getVariable ["FADE_pickHostageIdentity", {}];
    private _identityNameFn = missionNamespace getVariable ["FADE_getIdentityDisplayName", {}];
    private _usedHvtCodenames = [];
    private _usedHostageIds = [];
    private _zoneTargetAssigns = [];
    private _zoneSummaryLines = [];
    {
        private _variant = _zoneVariantsPlanned select _forEachIndex;
        private _grid = mapGridPosition (_x select 1);
        private _codename = _zoneCodenames select _forEachIndex;
        private _targetName = "";
        private _assign = [];
        switch (_variant) do {
            case "KillHVT";
            case "CaptureHVT": {
                if (_pickHvtFn isEqualType {}) then {
                    private _cn = [_usedHvtCodenames] call _pickHvtFn;
                    _usedHvtCodenames pushBack _cn;
                    _targetName = _cn;
                    _assign = ["hvt", _cn];
                };
            };
            case "RecoverHostage": {
                if (_pickHostageFn isEqualType {}) then {
                    private _idKey = [_usedHostageIds] call _pickHostageFn;
                    _usedHostageIds pushBack _idKey;
                    _targetName = if (_identityNameFn isEqualType {}) then { [_idKey] call _identityNameFn } else { _idKey };
                    _assign = ["hostage", _idKey];
                };
            };
        };
        _zoneTargetAssigns pushBack _assign;
        private _detail = switch (_variant) do {
            case "KillHVT";
            case "CaptureHVT": { format ["HVT %1 (%2 network)", _targetName, _cellName] };
            case "RecoverHostage": { format ["hostage %1 (%2 network)", _targetName, _cellName] };
            default {
                private _objName = [] call (missionNamespace getVariable ["FADE_getRecoverObjectDisplayName", { "priority package" }]);
                format ["recover %1 (%2 network) — likely indoors in a defended building", _objName, _cellName]
            };
        };
        _zoneSummaryLines pushBack format [
            "%1 (Grid %2): %3 — %4",
            _codename,
            _grid,
            (_variantLabels getOrDefault [_variant, _variant]),
            _detail
        ];
    } forEach _zonesPicked;

    private _raidCenter = [0, 0, 0];
    { private _p = _x select 1; _raidCenter = [(_raidCenter select 0) + (_p select 0), (_raidCenter select 1) + (_p select 1), 0] } forEach _zonesPicked;
    _raidCenter = [(_raidCenter select 0) / (count _zonesPicked), (_raidCenter select 1) / (count _zonesPicked), 0];

    if (!isNil "FADE_lore_generate") then {
        private _opName = missionNamespace getVariable ["FADE_missionRun_operationName", ""];
        private _loreResult = ["Raid", _raidCenter, _opName] call FADE_lore_generate;
        if (_loreResult isEqualType [] && { count _loreResult >= 3 }) then {
            _loreResult params ["_ls", "_ldiary", "_lsmeac"];
            if (_ls != "") then { _loreShort = _ls };
            if (_ldiary != "") then { _loreLong = _ldiary };
            if (_lsmeac != "") then { _loreSmeacHtml = _lsmeac };
        };
    };
    missionNamespace setVariable ["FADE_missionRun_loreShort", _loreShort];
    missionNamespace setVariable ["FADE_missionRun_loreLong", _loreLong];
    missionNamespace setVariable ["FADE_missionRun_loreSmeacHtml", _loreSmeacHtml];
    private _hqBoardFnRaid = missionNamespace getVariable ["FADE_hqMainBoard_setObjectiveBrief", {}];
    if (_hqBoardFnRaid isEqualType {} && { !(_hqBoardFnRaid isEqualTo {}) }) then { [_raidCenter] call _hqBoardFnRaid };

    private _topoRaid = [_raidCenter] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "Unknown area"] }]);
    private _raidExecText = format [
        "<t align='left' color='#C0C0C0'>Intel starts approximate — recon or contact refines each site.</t><br/>" +
        "<t align='left' color='#C0C0C0'>Committed assault may draw enemy attention and follow-on forces.</t><br/>" +
        "<t align='left' color='#C0C0C0'>Clear objectives in any order; follow map markers and child tasks.</t>"
    ];
    if ("RecoverObject" in _zoneVariantsPlanned) then {
        private _recoverObjName = [] call (missionNamespace getVariable ["FADE_getRecoverObjectDisplayName", { "priority package" }]);
        _raidExecText = _raidExecText + format [
            "<br/><t align='left' color='#C0C0C0'>Recover-object objectives: %1 — most likely indoors inside defended buildings.</t>",
            _recoverObjName
        ];
    };
    private _raidSituationText = if (_intelFormatter isEqualTo {}) then {
        format [
            "<t align='left' color='#FFD166'>ENEMY</t><br/><t align='left' color='#B0B0B0'>%1 — garrisons at %2 separate sites.</t>",
            _enemyFactionName,
            _raidZoneCount
        ]
    } else {
        [
            "Raid",
            _raidCenter,
            _sideEnemy,
            _sideFriendly,
            _estimatedOpforCount,
            _opforCountFactor,
            _enemyFactionName,
            _friendlyFactionName,
            _friendlyPlayerCount,
            (_topoRaid select 0),
            (_topoRaid select 1)
        ] call _intelFormatter
    };
    private _raidMissionDesc = format [
        "RAID: clear %1 objectives linked to network %2 (%3).<br/><br/><t align='left' color='#C9D4A0'>Objectives</t><br/><t align='left' color='#C0C0C0'>%4</t>",
        _raidZoneCount,
        _cellName,
        ((_zoneVariantsPlanned apply { _variantLabels getOrDefault [_x, _x] }) joinString ", "),
        (_zoneSummaryLines joinString "<br/>")
    ];
    [_player, _taskId, _raidMissionDesc, "Raid", _raidCenter, "attack", _raidSituationText, _raidExecText] call _fnc_createMissionTask;

    private _zoneStateArr = [];
    for "_i" from 1 to _raidZoneCount do { _zoneStateArr pushBack "PENDING" };
    missionNamespace setVariable ["FADE_raidZoneState_" + _taskId, _zoneStateArr];
    missionNamespace setVariable ["FADE_raidAborted_" + _taskId, false];

    // ---- Pass 2: spawn zones ----
    private _spawnFailed = false;
    for "_zi" from 0 to (_raidZoneCount - 1) do {
        private _zoneEntry = _zonesPicked select _zi;
        private _zoneCenter = _zoneEntry select 1;
        private _plannedVariant = _zoneVariantsPlanned select _zi;
        private _zoneNum = _zi + 1;
        private _zoneCodename = _zoneCodenames select _zi;
        private _childTaskId = format ["%1_raid_obj_%2", _taskId, _zoneNum];
        private _zoneMarkerName = format ["FADE_raid_%1_%2", _taskId, _zoneNum];
        private _zoneEllipseName = _zoneMarkerName + "_zone";

        private _diffMul = [_zi, _friendlyPlayerCount] call FADE_raid_zoneDifficultyMul;

        private _spawnResult = [_plannedVariant, _zoneCenter, _sideEnemy, _enemyUnitsRaid, _diffMul, _childTaskId, _taskId, (_zoneTargetAssigns select _zi)] call FADE_raid_spawnZone;
        _spawnResult params ["_spawnOk", "_actualVariant", "_zoneGroups", "_zoneObjects", "_zoneWinPos", "_watcherPayload"];

        if (!_spawnOk) exitWith {
            _spawnFailed = true;
            missionNamespace setVariable ["FADE_raidAborted_" + _taskId, true];
            [_player] call FADE_clearActiveMission;
            [_player, "MISSION ERROR", format [
                "Could not set up objective %1 (%2). Try another map area or abort and restart.",
                _zoneCodename,
                (_variantLabels getOrDefault [_plannedVariant, _plannedVariant])
            ]] call FADE_missionErrorHint;
            [_taskId, "FAILED"] call BIS_fnc_taskSetState;
        };

        [_taskId, _zoneGroups] call FADE_missionEnt_bindGroups;
        { if (!isNull _x) then { [_taskId, _x] call FADE_missionEnt_registerObject } } forEach _zoneObjects;
        [_taskId, _zoneMarkerName] call FADE_missionEnt_registerMarker;
        [_taskId, _zoneEllipseName] call FADE_missionEnt_registerMarker;
        [_zoneGroups, _basePos] call FADE_registerEnemyRetreat;

        [_taskId, _zoneEllipseName, _zoneCenter, _intelApproxRadius, _markerEnemy] call FADE_mission_createRadiusMarker;
        private _zMarker = createMarker [_zoneMarkerName, [_zoneCenter] call FADE_normPos3];
        _zMarker setMarkerType "o_unknown";
        _zMarker setMarkerColor _markerEnemy;
        _zMarker setMarkerText _zoneCodename;

        if (_zi == 0) then {
            [_sideFriendly, _zoneMarkerName] call FADE_raid_assignMarkersToFriendlies;
        };

        [_taskId, _childTaskId, _zoneMarkerName, _zoneEllipseName, _zoneCenter, _zoneWinPos, _zoneDetectRadius, _intelApproxRadius, _intelRefineRadius] call FADE_raid_startIntelMonitor;

        private _zoneTargetName = "";
        if (_actualVariant in ["KillHVT", "CaptureHVT", "RecoverHostage"] && { _watcherPayload isEqualType [] } && { count _watcherPayload > 0 } && { !isNull (_watcherPayload select 0) }) then {
            _zoneTargetName = name (_watcherPayload select 0);
        };
        if (_zoneTargetName == "") then {
            private _assign = _zoneTargetAssigns select _zi;
            if (_assign isEqualType [] && { count _assign >= 2 }) then {
                if (_assign select 0 == "hvt") then { _zoneTargetName = _assign select 1 };
                if (_assign select 0 == "hostage" && { _identityNameFn isEqualType {} }) then { _zoneTargetName = [_assign select 1] call _identityNameFn };
            };
        };
        if (_zoneTargetName != "") then {
            private _detailSpawned = switch (_actualVariant) do {
                case "KillHVT";
                case "CaptureHVT": { format ["HVT %1 (%2 network)", _zoneTargetName, _cellName] };
                case "RecoverHostage": { format ["hostage %1 (%2 network)", _zoneTargetName, _cellName] };
                default { format ["%1 asset", _cellName] };
            };
            _zoneSummaryLines set [
                _zi,
                format [
                    "%1 (Grid %2): %3 — %4",
                    _zoneCodename,
                    mapGridPosition _zoneCenter,
                    (_variantLabels getOrDefault [_actualVariant, _actualVariant]),
                    _detailSpawned
                ]
            ];
        };
        if (_actualVariant == "RecoverObject") then {
            private _objName = [] call (missionNamespace getVariable ["FADE_getRecoverObjectDisplayName", { "priority package" }]);
            _zoneSummaryLines set [
                _zi,
                format [
                    "%1 (Grid %2): %3 — recover %4 (%5 network) — likely indoors in a defended building",
                    _zoneCodename,
                    mapGridPosition _zoneCenter,
                    (_variantLabels getOrDefault [_actualVariant, _actualVariant]),
                    _objName,
                    _cellName
                ]
            ];
        };

        private _variantDesc = switch (_actualVariant) do {
            case "RecoverObject": {
                private _objName = [] call (missionNamespace getVariable ["FADE_getRecoverObjectDisplayName", { "priority package" }]);
                format [
                    "Recover %1 at %2 (Grid %3). Most likely indoors inside a defended building — use scroll action to secure it. Completes in place; no RTB required.",
                    _objName,
                    _zoneCodename,
                    mapGridPosition _zoneCenter
                ]
            };
            case "KillHVT": {
                format ["Eliminate HVT %1 at %2 (Grid %3).", _zoneTargetName, _zoneCodename, mapGridPosition _zoneCenter]
            };
            case "CaptureHVT": {
                format ["Capture HVT %1 at %2 (Grid %3) and return them (handcuffed/captive) within %4 m of base.", _zoneTargetName, _zoneCodename, mapGridPosition _zoneCenter, _baseDistForComplete]
            };
            default {
                format ["Rescue hostage %1 at %2 (Grid %3) and return them alive within %4 m of base.", _zoneTargetName, _zoneCodename, mapGridPosition _zoneCenter, _baseDistForComplete]
            };
        };
        private _variantTitle = _variantLabels getOrDefault [_actualVariant, _actualVariant];
        [_childTaskId, _variantDesc, _variantTitle, _zoneCenter, "search"] call _fnc_createChildTask;

        [_taskId, _zoneWinPos, _basePos, _enemyUnitsRaid, _zoneGroups, _zoneDetectRadius, _raidQrfSkipDetection, _raidQrfFirstMin, _raidQrfFirstMax] call FADE_counterAttackStart;

        [_taskId, _childTaskId, _zi, _basePos, _baseDistForComplete, _actualVariant, _watcherPayload, _zoneMarkerName, _zoneWinPos, _zoneCodename] spawn {
            params ["_taskId", "_childTaskId", "_zi", "_basePos", "_baseDistForComplete", "_variant", "_payload", "_zoneMarkerName", "_zoneWinPos", "_zoneCodename"];
            private _done = false;
            private _result = "SUCCEEDED";
            private _payloadReady = _payload isEqualType [] && { count _payload > 0 };
            waitUntil {
                sleep 1;
                private _parentState = _taskId call BIS_fnc_taskState;
                if (_parentState == "CANCELED") exitWith {
                    _done = true;
                    _result = "CANCELED";
                    true
                };
                if (_parentState in ["SUCCEEDED", "FAILED"]) exitWith {
                    _done = true;
                    _result = if (_parentState == "SUCCEEDED") then { "SUCCEEDED" } else { "CANCELED" };
                    true
                };
                if (missionNamespace getVariable ["FADE_raidAborted_" + _taskId, false]) exitWith {
                    _done = true;
                    _result = "CANCELED";
                    true
                };
                switch (_variant) do {
                    case "RecoverObject": {
                        if (missionNamespace getVariable ["FADE_assetIntelTaken_" + _childTaskId, false]) then {
                            _done = true;
                            _result = "SUCCEEDED";
                        };
                    };
                    case "KillHVT": {
                        if (!_payloadReady) exitWith {};
                        private _hvt = _payload select 0;
                        if (!isNull _hvt && { !alive _hvt }) then {
                            _done = true;
                            _result = "SUCCEEDED";
                        };
                    };
                    case "CaptureHVT": {
                        if (!_payloadReady) exitWith {};
                        private _hvt = _payload select 0;
                        if (!isNull _hvt && { !alive _hvt }) then {
                            _done = true;
                            _result = "FAILED";
                        };
                        if (
                            !_done &&
                            { alive _hvt } &&
                            { _hvt getVariable ["ACE_captives_isHandcuffed", false] || { captive _hvt } } &&
                            { (_hvt distance _basePos) < _baseDistForComplete }
                        ) then {
                            _done = true;
                            _result = "SUCCEEDED";
                        };
                    };
                    default {
                        if (!_payloadReady) exitWith {};
                        private _hostage = _payload select 0;
                        if (!isNull _hostage && { !alive _hostage }) then {
                            _done = true;
                            _result = "FAILED";
                        };
                        if (!_done && { alive _hostage } && { (_hostage distance _basePos) < _baseDistForComplete }) then {
                            _done = true;
                            _result = "SUCCEEDED";
                        };
                    };
                };
                _done
            };
            if ((_childTaskId call BIS_fnc_taskState) in ["CREATED", "ASSIGNED"]) then {
                [_childTaskId, _result] call BIS_fnc_taskSetState;
            };
            if (_result == "SUCCEEDED" && { markerShape _zoneMarkerName != "" }) then {
                _zoneMarkerName setMarkerPos _zoneWinPos;
                _zoneMarkerName setMarkerType "mil_objective";
                _zoneMarkerName setMarkerText format ["%1 — CLEAR", _zoneCodename];
            };
            private _arr = +(missionNamespace getVariable ["FADE_raidZoneState_" + _taskId, []]);
            if (_zi >= 0 && { _zi < count _arr }) then {
                _arr set [_zi, _result];
                missionNamespace setVariable ["FADE_raidZoneState_" + _taskId, _arr];
            };
        };
    };

    if (_spawnFailed) exitWith {
        missionNamespace setVariable ["FADE_raidZoneState_" + _taskId, nil];
        missionNamespace setVariable ["FADE_raidAborted_" + _taskId, nil];
        [_taskId, "", _player, 5] call FADE_mission_completeCleanup;
    };

    // Refresh parent SMEAC now that zones (and target names) are spawned.
    private _raidMissionDescFinal = format [
        "RAID: clear %1 objectives linked to network %2 (%3).<br/><br/><t align='left' color='#C9D4A0'>Objectives</t><br/><t align='left' color='#C0C0C0'>%4</t>",
        _raidZoneCount,
        _cellName,
        ((_zoneVariantsPlanned apply { _variantLabels getOrDefault [_x, _x] }) joinString ", "),
        (_zoneSummaryLines joinString "<br/>")
    ];
    private _taskBuilder = missionNamespace getVariable ["FADE_buildMissionTaskSmeacText", {}];
    if (_taskBuilder isEqualType {} && { !(_taskBuilder isEqualTo {}) }) then {
        private _adminT = missionNamespace getVariable ["FADE_missionRun_defaultAdminTaskText", ""];
        private _cmdT = missionNamespace getVariable ["FADE_missionRun_defaultCommandTaskText", ""];
        private _newTaskDesc = [
            _raidMissionDescFinal,
            _raidCenter,
            _raidSituationText,
            _raidExecText,
            _adminT,
            _cmdT,
            false
        ] call _taskBuilder;
        [_taskId, [_newTaskDesc, "Raid", ""]] call BIS_fnc_taskSetDescription;
    };

    // ---- Brief + assigned intro ----
    private _grid0 = mapGridPosition _raidCenter;
    private _brief = format [
        "RAID (%1)%2%2Network: %3%2Operation area (approx.): Grid %4%2%2%5%2%2Clear all %6 objectives in any order. Map markers use codenames from the operation word list. Intel is approximate until recon refines each site.",
        _operationNameUpper,
        toString [10],
        _cellName,
        _grid0,
        (_zoneSummaryLines joinString (toString [10])),
        _raidZoneCount
    ] + _briefGuiTail;
    if (!isNull _player) then { _player setVariable ["FADE_myMissionBrief", _brief, true] };

    // Assigned intro (matches Operation / AO / Invasion — operation name + type only).
    private _starterName = if (isNull _player) then { "Unknown" } else { name _player };
    [_operationNameUpper, _starterName] remoteExec ["FADE_showMissionAssignedIntro", 0];
    if (_loreLong != "") then {
        private _whenStr = format ["Mission start +%1 min", floor (time / 60) max 0];
        private _opName = missionNamespace getVariable ["FADE_missionRun_operationName", ""];
        [_opName, _whenStr, _loreLong, "Background"] remoteExec ["FADE_client_appendMissionBackground", 0];
    };
    [_player, "Raid"] call FADE_notifyOthersMissionStarted;

    // ---- Master finalizer ----
    [_taskId, _player, _raidZoneCount, _raidTimeoutSec] spawn {
        params ["_taskId", "_player", "_raidZoneCount", "_timeoutSec"];
        private _finalState = "";
        private _startTime = time;
        waitUntil {
            sleep 1;
            if (_timeoutSec > 0 && { time - _startTime >= _timeoutSec }) exitWith {
                _finalState = "FAILED";
                true
            };
            if ((_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"]) exitWith {
                _finalState = _taskId call BIS_fnc_taskState;
                true
            };
            if (missionNamespace getVariable ["FADE_raidAborted_" + _taskId, false]) exitWith {
                _finalState = "CANCELED";
                true
            };
            private _arr = missionNamespace getVariable ["FADE_raidZoneState_" + _taskId, []];
            if (count _arr == _raidZoneCount && { (_arr findIf { _x == "PENDING" }) == -1 }) exitWith {
                if (("FAILED" in _arr) || { ({ _x == "CANCELED" } count _arr) == _raidZoneCount }) then {
                    _finalState = if ("FAILED" in _arr) then { "FAILED" } else { "CANCELED" };
                } else {
                    _finalState = "SUCCEEDED";
                };
                true
            };
            false
        };
        if (_finalState != "" && { (_taskId call BIS_fnc_taskState) in ["CREATED", "ASSIGNED"] }) then {
            [_taskId, _finalState] call BIS_fnc_taskSetState;
        };
        if (_finalState == "SUCCEEDED") then {
            [_player, "All raid objectives cleared."] call FADE_missionSuccessHint;
        };
        if (_finalState == "FAILED") then {
            private _arrF = missionNamespace getVariable ["FADE_raidZoneState_" + _taskId, []];
            private _failMsg = if (_timeoutSec > 0 && { time - _startTime >= _timeoutSec }) then {
                "Raid timed out before all objectives were cleared."
            } else {
                if ("FAILED" in _arrF) then {
                    "A raid objective failed — hostage lost or capture HVT was killed."
                } else {
                    "Raid failed."
                }
            };
            [_player, _failMsg] call FADE_missionFailHint;
        };
        [_taskId, "", _player, 60] call FADE_mission_completeCleanup;
        missionNamespace setVariable ["FADE_raidZoneState_" + _taskId, nil];
        missionNamespace setVariable ["FADE_raidAborted_" + _taskId, nil];
    };
};
