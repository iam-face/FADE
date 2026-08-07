// ServerGameplayMissionsCore.sqf - FADE_startMission and slot orchestration

// -----------------------------------------------------------------------------
// Start mission (server). Global: 1 at a time. Single: up to 3. Locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_startMission = {
    params [
        "_missionType", "_player", ["_anchorPos", []], ["_friendlyFaction", ""], ["_enemyFaction", ""],
        ["_civFaction", ""], ["_convoyEndPos", []], ["_raidZoneClicks", []]
    ];
    if (isNull _player) exitWith {};
    private _bypassDisabled = missionNamespace getVariable ["FADE_startMission_bypassDisabled", false];
    if (!_bypassDisabled && { _missionType in (missionNamespace getVariable ["FADE_disabledMissionTypes", []]) }) exitWith {
        private _lbl = [_missionType] call (missionNamespace getVariable ["FADE_missionTypeDisplayName", { _this select 0 }]);
        [_player, "MISSION UNAVAILABLE", format ["%1 is temporarily disabled.", _lbl]] call FADE_missionErrorHint;
    };
    private _raidZoneCount = (round (missionNamespace getVariable ["FADE_raidObjectiveCount", 3])) max 2 min 5;
    private _useRaidMultiPick = (
        _missionType == "Raid" &&
        { _raidZoneClicks isEqualType [] } &&
        { count _raidZoneClicks >= _raidZoneCount }
    );
    private _useMapAnchor = if (_useRaidMultiPick) then { true } else { [_anchorPos] call FADE_fnc_isValidMapClickPos };
    private _useConvoyEnd = [_convoyEndPos] call FADE_fnc_isValidMapClickPos;
    if (!_useRaidMultiPick && { _useMapAnchor && { surfaceIsWater _anchorPos }}) exitWith {
        [_player, "MISSION ERROR", "Invalid map location (water)."] call FADE_missionErrorHint;
    };
    if (_useConvoyEnd && { surfaceIsWater _convoyEndPos }) exitWith {
        [_player, "MISSION ERROR", "Invalid convoy end (water)."] call FADE_missionErrorHint;
    };
    if (_missionType == "EscapeEvasion") exitWith {
        ["<t size='1.2' color='#FFAA00'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>Use START on this mission to open the evadee list (you must include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_missionType == "TroopInsert") exitWith {
        ["<t size='1.2' color='#FFAA00'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Use START to open the participant list (pilots/drivers; include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_missionType == "TroopExtract") exitWith {
        ["<t size='1.2' color='#FFAA00'>TROOP EXTRACT</t><br/><br/><t color='#E0E0E0'>Use START to open the participant list (pilots/drivers; include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_missionType == "GeoGuesser") exitWith {
        ["<t size='1.2' color='#FFAA00'>GEO-GUESSER</t><br/><br/><t color='#E0E0E0'>Use START to open the participant list, timer, and difficulty (include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (!([_player] call FADE_playerCanUseMissionsGui)) exitWith {
        ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _ff = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _factionIssue = [_ff, _ef] call FADE_scenarioFactionsDescribeIssue;
    if (_factionIssue != "") exitWith {
        [_player, "SCENARIO ERROR", "Friendly and enemy factions are incompatible. Open Manage Scenario → Factions and Apply."] call FADE_missionErrorHint;
    };
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion", "PointDefense"];
    if (_spawnsEnemies && { count ([] call FADE_resolveScenarioEnemyUnits) == 0 }) exitWith {
        [_player, "MISSION ERROR", "No enemy units configured for the chosen enemy faction."] call FADE_missionErrorHint;
    };
    private _playerUid = getPlayerUID _player;
    private _isGlobal = _missionType in (missionNamespace getVariable ["FADE_globalMissionTypes", []]);
    private _isSingle = _missionType in (missionNamespace getVariable ["FADE_singleMissionTypes", []]);
    if (!_isGlobal && { !_isSingle }) exitWith {
        [_player, "MISSION ERROR", "Unknown mission type."] call FADE_missionErrorHint;
    };
    // Player may only have one mission (global or one single)
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    if ((count _global >= 1 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) || { { [_x, _player] call FADE_isMissionEntryOwnedByPlayer } count _singleList > 0 }) exitWith {
        [_player, "active"] call FADE_missionSlotGateHint;
    };
    if (_isGlobal && { count _global >= 1 }) exitWith {
        [_player, "global"] call FADE_missionSlotGateHint;
    };
    if (_isSingle && { count _singleList >= 3 }) exitWith {
        [_player, "slotsFull"] call FADE_missionSlotGateHint;
    };
    private _needsLZ = _missionType in ["TroopInsert", "TroopExtract", "Cargo", "CASEVAC", "CSAR"];
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "Raid", "Invasion", "EscapeEvasion", "PointDefense"];
    private _minDistForPos = if (_spawnsEnemies) then { 1000 } else { FADE_minDistFromBase };
    if (_missionType in ["TroopInsert", "TroopExtract"]) then {
        _minDistForPos = _minDistForPos max FADE_troopInsertExtractMinDistFromBase;
    };
    private _destPos = [];
    private _attempt = 0;
    private _maxAttempts = 25;
    private _mapPickRadius = -1;
    private _snappedZone = [];
    private _rawAnchor = if (_useMapAnchor) then { +_anchorPos } else { [] };
    private _rawConvoyEnd = if (_useConvoyEnd) then { +_convoyEndPos } else { [] };
    private _convoyEndResolved = [];
    if (_useRaidMultiPick) then {
        // #region agent log
        diag_log format ["#DBGa783a2 {""sessionId"":""a783a2"",""hypothesisId"":""H2"",""location"":""ServerGameplayMissions.sqf:startMission"",""message"":""raid multi-pick received"",""data"":{""zoneCount"":%1,""clicks"":%2},""timestamp"":%3}", _raidZoneCount, _raidZoneClicks, diag_tickTime];
        // #endregion
        private _minZoneD = missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000];
        private _clicks = +_raidZoneClicks select [0, _raidZoneCount];
        private _spacingOk = true;
        for "_i" from 0 to ((count _clicks) - 2) do {
            for "_j" from (_i + 1) to ((count _clicks) - 1) do {
                if (((_clicks select _i) distance2D (_clicks select _j)) < _minZoneD) exitWith { _spacingOk = false };
            };
            if (!_spacingOk) exitWith {};
        };
        if (!_spacingOk) exitWith {
            [_player, "MISSION ERROR", format ["Raid zones must be at least %1 m apart. Try again.", _minZoneD]] call FADE_missionErrorHint;
        };
        {
            if (surfaceIsWater _x) exitWith {
                [_player, "MISSION ERROR", format ["Invalid raid zone %1 (water).", _forEachIndex + 1]] call FADE_missionErrorHint;
                _spacingOk = false;
            };
        } forEach _clicks;
        if (!_spacingOk) exitWith {};
        private _centroid = [0, 0, 0];
        { _centroid = [(_centroid select 0) + (_x select 0), (_centroid select 1) + (_x select 1), 0] } forEach _clicks;
        _destPos = [(_centroid select 0) / (count _clicks), (_centroid select 1) / (count _clicks), 0];
        _rawAnchor = +(_clicks select 0);
        _mapPickRadius = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
        [
            format [
                "<t size='1.1' color='#A0D0A0'>Raid zones set</t><br/><t color='#808080'>%1</t>",
                ((_clicks apply { mapGridPosition _x }) joinString " · ")
            ]
        ] remoteExec ["FADE_showMissionHint", _player];
    } else {
    if (_missionType == "InterceptConvoy" && { _useMapAnchor } && { _useConvoyEnd }) then {
        private _route = [FADE_basePos, -1, _anchorPos, -1, _convoyEndPos] call FADE_interceptConvoyRoadRoute;
        if (_route isEqualTo []) exitWith {
            [_player, "MISSION ERROR", "Could not build a convoy route from your start and end clicks (need roads near each point, both away from base). Try different points or use Random."] call FADE_missionErrorHint;
        };
        _route params ["_routeStart", "_routeEnd"];
        _destPos = +_routeStart;
        _convoyEndResolved = +_routeEnd;
        [
            format [
                "<t size='1.1' color='#A0D0A0'>Convoy route set</t><br/><t color='#808080'>Start: grid %1<br/>End: grid %2</t>",
                mapGridPosition _routeStart,
                mapGridPosition _routeEnd
            ]
        ] remoteExec ["FADE_showMissionHint", _player];
    } else {
        if (_useMapAnchor) then {
            private _pick = [_anchorPos, _missionType, _minDistForPos, _needsLZ] call FADE_fnc_pickMissionDestNearMapClick;
            _pick params ["_picked", "_usedR", "_snapped"];
            _destPos = _picked;
            _mapPickRadius = _usedR;
            _snappedZone = _snapped;
            // #region agent log
            if (_missionType == "AssetRetrieval") then {
                private _snapDist = if (count _snapped >= 2) then { round (_snapped distance2D _anchorPos) } else { -1 };
                private _destDist = if (count _picked >= 2) then { round (_picked distance2D _anchorPos) } else { -1 };
                diag_log format ["#DBGc2f21e {""sessionId"":""c2f21e"",""hypothesisId"":""C"",""location"":""ServerGameplayMissionsCore.sqf:mapPick"",""message"":""AssetRetrieval map pick resolved"",""data"":{""click"":%1,""dest"":%2,""snapped"":%3,""usedR"":%4,""snapDistM"":%5,""destDistM"":%6},""timestamp"":%7}", _anchorPos, _picked, _snapped, _usedR, _snapDist, _destDist, diag_tickTime];
            };
            // #endregion
        } else {
            while { _attempt < _maxAttempts } do {
                _attempt = _attempt + 1;
                _destPos = [_missionType, _minDistForPos, _needsLZ, []] call FADE_startMission_pickDestPos;
                if (count _destPos >= 2 && { _missionType in ["InterceptConvoy", "Operation", "Raid", "Invasion"] || { [_destPos] call FADE_missionPosClear } }) exitWith {};
            };
        };
    };
    };
    if (count _destPos < 2 && { _missionType != "InterceptConvoy" } && { _missionType != "AreaOfOperations" }) exitWith {
        private _snapTypes = missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []];
        private _mapSuffix = if (_useMapAnchor) then {
            if (_missionType in _snapTypes) then {
                " NO VALID SITE AT THE NEAREST CIV ZONE (or too close to other missions) � TRY ANOTHER CLICK OR USE RANDOM."
            } else {
                " NO VALID LOCATION NEAR YOUR MAP CLICK (searched 250 m ? whole map) � TRY ANOTHER AREA OR USE RANDOM."
            }
        } else { "" };
        private _msg = if (_missionType == "HVT" || { _missionType == "Hostage" } || { _missionType == "SearchDestroy" }) then {
            "NO VALID URBAN AREA NEAR A CIV ZONE. TRY AGAIN OR USE A MAP WITH MORE NAMED SETTLEMENTS."
        } else {
            if (_missionType == "AssetRetrieval") then {
                "NO SUITABLE BUILDING (6+ ROOMS) NEAR A CIV ZONE, OR ZONES TOO CLOSE TO BASE."
            } else {
                if (_missionType == "MineClearing") then {
                    "NO SPOT NEAR A CIV ZONE WITHIN 500 M, OR ZONES TOO CLOSE TO BASE."
                } else {
                    if (_missionType == "TroopExtract") then {
                        "NO TROOP EXTRACT PICKUP SPOT NEAR A CIV ZONE WITHIN 250 M."
                    } else {
                        if (_needsLZ) then { "NO VALID LZ. CLEAR OF OBSTACLES REQUIRED. TRY AGAIN." } else { "NO VALID POSITION (or too close to other missions). TRY AGAIN." };
                    };
                };
            };
        };
        [_player, "MISSION ERROR", format ["%1%2", _msg, _mapSuffix]] call FADE_missionErrorHint;
    };
    if (count _destPos >= 2 && { !([_destPos] call FADE_missionPosClear) } && { !(_missionType in ["InterceptConvoy", "Operation", "Raid", "Invasion"]) }) exitWith {
        [_player, "MISSION ERROR", "No position at least 2 km from other missions. Try again."] call FADE_missionErrorHint;
    };

    if (_useMapAnchor && { count _destPos >= 2 } && { _missionType != "InterceptConvoy" || { !_useConvoyEnd } } && { !_useRaidMultiPick }) then {
        [_player, _destPos, _rawAnchor, _snappedZone, _mapPickRadius] call FADE_fnc_mapPickResultHint;
    };

    if (_isGlobal) then {
        private _operationName = [] call FADE_generateOperationName;
        missionNamespace setVariable ["FADE_globalMission", [_missionType, _player, _destPos, _playerUid, _operationName]];
        missionNamespace setVariable ["FADE_currentMissionType", _missionType];
        missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
        [] call FADE_missionSlots_publish;
    } else {
        private _operationName = [] call FADE_generateOperationName;
        _singleList pushBack [_missionType, _player, _destPos, _playerUid, _operationName];
        missionNamespace setVariable ["FADE_singleMissions", _singleList];
        [] call FADE_missionSlots_publish;
    };
    // Spawn + compile (not execVM): avoids FADE_missionParams being overwritten by another
    // player's FADE_startMission before this Missions.sqf run reads line 1.
    [_missionType, _destPos, _player, _useMapAnchor, _rawAnchor, _snappedZone, _mapPickRadius, _rawConvoyEnd, _convoyEndResolved, _raidZoneClicks] spawn {
        params ["_missionType", "_destPos", "_player", "_useMapAnchor", "_rawAnchor", "_snappedZone", "_resolvedRadius", "_rawConvoyEnd", "_convoyEndResolved", "_raidZoneClicks"];
        if (_missionType == "InterceptConvoy" && { !isNull _player }) then {
            ["INTERCEPT CONVOY: Setting up mission — spawning convoy, please wait..."] remoteExec ["systemChat", _player];
        };
        if (_missionType == "AssetRetrieval" && { !isNull _player }) then {
            ["ASSET RETRIEVAL: Setting up mission — please wait..."] remoteExec ["systemChat", _player];
        };
        private _anchor = [];
        if (_useMapAnchor) then {
            if (count _snappedZone >= 2) then {
                _anchor = +_snappedZone;
            } else {
                if ([_rawAnchor] call FADE_fnc_isValidMapClickPos) then { _anchor = +_rawAnchor };
            };
        };
        FADE_missionParams = [
            _missionType, _destPos, _player, [], _useMapAnchor,
            [_rawAnchor, _anchor, _snappedZone, _resolvedRadius, _rawConvoyEnd, _convoyEndResolved, _raidZoneClicks]
        ];
        [] call FADE_profile_missionStartMark;
        if (isNil "FADE_runMission") then { [] call FADE_installMissionModules };
        [] call FADE_runMission;
    };
};