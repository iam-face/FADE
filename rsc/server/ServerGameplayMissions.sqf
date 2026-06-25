// =============================================================================
// ServerGameplayMissions.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// -----------------------------------------------------------------------------
// Mission streams: Global (1 at a time, heavy) vs Single (up to 3, lighter). All locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_globalMissionTypes = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "InterceptConvoy", "SearchDestroy", "Operation", "AssetRetrieval", "CSAR", "EscapeEvasion"];
FADE_singleMissionTypes = ["TroopInsert", "TroopExtract", "Cargo", "MineClearing", "CASEVAC"];
FADE_minDistBetweenMissions = 2000;
missionNamespace setVariable ["FADE_globalMission", []];
missionNamespace setVariable ["FADE_singleMissions", []];
missionNamespace setVariable ["FADE_currentMissionType", ""];
missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
[] call FADE_missionSlots_publish;
publicVariable "FADE_globalMissionTypes";
publicVariable "FADE_singleMissionTypes";
publicVariable "FADE_minDistBetweenMissions";

// Mission owner check supports respawned player objects via UID fallback.
FADE_isMissionEntryOwnedByPlayer = {
    params ["_entry", "_player"];
    if (isNull _player || { !(_entry isEqualType []) }) exitWith { false };
    private _entryOwnerObj = _entry param [1, objNull];
    private _entryOwnerUid = _entry param [3, ""];
    private _playerUid = getPlayerUID _player;
    (_entryOwnerObj == _player) || { _entryOwnerUid != "" && { _entryOwnerUid == _playerUid } }
};

FADE_generateOperationName = {
    private _partA = missionNamespace getVariable ["FADE_operationNamePartA", []];
    private _partB = missionNamespace getVariable ["FADE_operationNamePartB", []];
    if (_partA isEqualTo [] || { _partB isEqualTo [] }) exitWith { "Operation Iron Resolve" };
    format ["Operation %1 %2", selectRandom _partA, selectRandom _partB]
};

// Notify all other players (systemChat) when a mission starts; initial assigned hint is broadcast for global missions (see Missions.sqf / AO / Operation scripts)
FADE_notifyOthersMissionStarted = {
    params ["_player", "_missionDisplayName"];
    private _others = allPlayers select { !isNull _x && { _x != _player } };
    { [format ["%1 started %2 (mission task is for them only).", name _player, _missionDisplayName]] remoteExec ["systemChat", _x] } forEach _others;
};

// Returns true if _pos is at least FADE_minDistBetweenMissions from global and all single mission positions
FADE_missionPosClear = {
    params ["_pos"];
    if (count _pos < 2) exitWith { false };
    private _minDist = missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    if (count _global >= 3) then {
        if ((_global select 2) distance _pos < _minDist) exitWith { false };
    };
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    {
        if (count (_x select 2) >= 2 && { ((_x select 2) distance _pos) < _minDist }) exitWith { false };
    } forEach _singleList;
    true;
};

// -----------------------------------------------------------------------------
// Escape & Evasion (server): _evadeeUids must include _player's UID. Picks civ zone >= 4 km from base; Missions.sqf handles spawn/QRF.
// -----------------------------------------------------------------------------
FADE_startEscapeEvasion = {
    params ["_evadeeUids", "_player"];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    if (!(_evadeeUids isEqualType [])) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Invalid evadee list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (!([_player] call FADE_playerCanUseMissionsGui)) exitWith {
        ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _playerUid = getPlayerUID _player;
    if !(_playerUid in _evadeeUids) exitWith {
        ["<t size='1.2' color='#FF6666'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>You must include yourself in the evadee list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    if ((count _global >= 1 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) || { { [_x, _player] call FADE_isMissionEntryOwnedByPlayer } count _singleList > 0 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have a mission. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _global >= 1) exitWith {
        ["<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>A global mission is in progress. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _evadees = [];
    private _missing = false;
    {
        private _uid = _x;
        if (!(_uid isEqualType "") || { _uid == "" }) then { _missing = true };
        private _p = objNull;
        { if (getPlayerUID _x == _uid) exitWith { _p = _x } } forEach allPlayers;
        if (isNull _p || { !alive _p } || { !isPlayer _p } || { side group _p != _sideFriendly }) then {
            _missing = true;
        } else {
            _evadees pushBack _p;
        };
    } forEach _evadeeUids;
    if (_missing || { count _evadees == 0 }) exitWith {
        ["<t size='1.2' color='#FF6666'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>One or more selected players are unavailable (disconnect, dead, or wrong side).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _seen = [];
    _evadees = _evadees select {
        private _u = getPlayerUID _x;
        if (_u in _seen) then { false } else { _seen pushBack _u; true };
    };
    private _baseQ = FADE_basePos;
    if (_baseQ isEqualType objNull) then { _baseQ = getPosATL _baseQ };
    if (count _baseQ < 3) then { _baseQ = [(_baseQ select 0), (_baseQ select 1), (_baseQ param [2, 0])] };
    private _minZoneDist = 4000;
    private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _zones = _zones call BIS_fnc_arrayShuffle;
    private _zoneCenter = [];
    private _zi = 0;
    while { _zi < count _zones && { count _zoneCenter < 2 } } do {
        private _tn = _zones select _zi;
        _zi = _zi + 1;
        private _tr = missionNamespace getVariable [_tn, objNull];
        if (isNull _tr) then { continue };
        private _zc = getPosATL _tr;
        if (count _zc >= 2 && { (_zc distance2D _baseQ) >= _minZoneDist } && { [_zc] call FADE_missionPosClear }) then {
            _zoneCenter = [(_zc select 0), (_zc select 1), (_zc param [2, 0])];
        };
    };
    if (count _zoneCenter < 2) exitWith {
        ["<t size='1.2' color='#FF6666'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>No civ zone is at least 4 km from base and clear of other missions. Adjust HQ / zone rules or abort other missions.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    // Enemy patrols must be on (ambient patrols + dynamic roadblocks). Mirror Scenario GUI Apply.
    missionNamespace setVariable ["FADE_scenarioPatrols", true, true];
    missionNamespace setVariable ["FAC_scenarioGui_patrols", true, true];
    private _operationName = [] call FADE_generateOperationName;
    missionNamespace setVariable ["FADE_globalMission", ["EscapeEvasion", _player, _zoneCenter, _playerUid, _operationName]];
    missionNamespace setVariable ["FADE_currentMissionType", "EscapeEvasion"];
    missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
    [] call FADE_missionSlots_publish;
    ["EscapeEvasion", _zoneCenter, _player, _evadees] spawn {
        params ["_missionType", "_destPos", "_player", "_evadees"];
        FADE_missionParams = [_missionType, _destPos, _player, _evadees];
        [] call FADE_profile_missionStartMark;
        if (isNil "FADE_runMission") then { [] call FADE_installMissionModules };
        [] call FADE_runMission;
    };
};

// -----------------------------------------------------------------------------
// Troop Insert (server): participating UIDs + oneOff|recurring. Picks LZ; runs compile-once FADE_troopInsertMissionMain.
// -----------------------------------------------------------------------------
FADE_startTroopInsert = {
    params ["_participantUids", "_mode", "_player", ["_lzAnchor", []]];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    if (!(_participantUids isEqualType [])) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Invalid participant list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (!([_player] call FADE_playerCanUseMissionsGui)) exitWith {
        ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _playerUid = getPlayerUID _player;
    if !(_playerUid in _participantUids) exitWith {
        ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>You must include yourself in the participating list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if !(_mode in ["oneOff", "recurring"]) then { _mode = "oneOff" };
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    if ((count _global >= 1 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) || { { [_x, _player] call FADE_isMissionEntryOwnedByPlayer } count _singleList > 0 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have a mission. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _global >= 1) exitWith {
        ["<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>A global mission is in progress. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _singleList >= 3) exitWith {
        ["<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>Three single missions are active. Wait for one to finish.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _participants = [];
    private _missing = false;
    {
        private _uid = _x;
        private _p = objNull;
        { if (getPlayerUID _x == _uid) exitWith { _p = _x } } forEach allPlayers;
        if (isNull _p || { !alive _p } || { !isPlayer _p } || { side group _p != _sideFriendly }) then {
            _missing = true;
        } else {
            _participants pushBack _p;
        };
    } forEach _participantUids;
    if (_missing || { count _participants == 0 }) exitWith {
        ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>One or more selected players are unavailable.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _busyParticipant = objNull;
    {
        if (_x != _player && { (_x getVariable ["FADE_myMission", ""]) != "" }) exitWith { _busyParticipant = _x };
        private _uid = getPlayerUID _x;
        {
            if ((_y param [3, ""]) == _uid) exitWith { _busyParticipant = _x };
        } forEach _singleList;
    } forEach _participants;
    if (!isNull _busyParticipant) exitWith {
        [format [
            "<t size='1.2' color='#FFAA00'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>%1 already has an active mission.</t>",
            name _busyParticipant
        ]] remoteExec ["FADE_showMissionHint", _player];
    };
    private _minDistForPos = FADE_troopInsertExtractMinDistFromBase max FADE_minDistFromBase;
    private _lzMinFromPickup = FADE_troopInsertLzMinDistFromPickup;
    private _pickupRef = [0, 0, 0];
    private _bSp = objNull;
    if (count FADE_bSpPoints > 0) then {
        _bSp = selectRandom FADE_bSpPoints;
        if (!isNull _bSp) then { _pickupRef = position _bSp };
    };
    private _destPos = [];
    private _lzMinStrict = _lzMinFromPickup;
    private _lzMinRelaxed = (_lzMinFromPickup * 0.7) max 1500;
    private _useLzAnchor = [_lzAnchor] call FADE_fnc_isValidMapClickPos;
    private _snappedZone = [];
    private _mapPickRadius = -1;
    if (_useLzAnchor) then {
        private _pick = [_lzAnchor, _minDistForPos, _pickupRef, _lzMinStrict, _lzMinRelaxed] call FADE_fnc_pickTroopInsertLzNearMapClick;
        _pick params ["_picked", "_usedR", "_snapped"];
        _destPos = _picked;
        _mapPickRadius = _usedR;
        _snappedZone = _snapped;
    };
    if (count _destPos < 2) then {
        for "_pass" from 0 to 1 do {
            private _needDist = if (_pass == 0) then { _lzMinStrict } else { _lzMinRelaxed };
            for "_attempt" from 0 to 30 do {
                private _cand = [_minDistForPos] call FADE_findMissionPos;
                if (count _cand >= 2) then {
                    private _lz = [_cand] call FADE_findSafeLZ;
                    if (
                        count _lz >= 2
                        && { [_lz] call FADE_missionPosClear }
                        && { _lz distance2D _pickupRef >= _needDist }
                    ) exitWith { _destPos = _lz };
                };
            };
            if (count _destPos >= 2) exitWith {};
        };
    };
    if (count _destPos < 2) exitWith {
        private _mapSuffix = if (_useLzAnchor) then {
            " NO VALID LZ NEAR YOUR MAP CLICK (searched 250 m ? whole map) � TRY ANOTHER AREA OR USE RANDOM."
        } else { "" };
        [format [
            "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No valid LZ (need clear ground at least 2.5 km from base pickup).%1</t>",
            _mapSuffix
        ]] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_useLzAnchor && { count _destPos >= 2 }) then {
        [_player, _destPos, _lzAnchor, _snappedZone, _mapPickRadius] call FADE_fnc_mapPickResultHint;
    };
    private _operationName = [] call FADE_generateOperationName;
    _singleList pushBack ["TroopInsert", _player, _destPos, _playerUid, _operationName];
    missionNamespace setVariable ["FADE_singleMissions", _singleList];
    missionNamespace setVariable ["FADE_currentMissionType", "TroopInsert"];
    missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
    [] call FADE_missionSlots_publish;
    ["TroopInsert", _destPos, _player, _participants, _mode] spawn {
        params ["_missionType", "_destPos", "_player", "_participants", "_mode"];
        if (isNil "FADE_troopInsertMissionMain") then { [] call FADE_installMissionModules };
        FADE_troopInsertParams = [_missionType, _destPos, _player, _participants, _mode];
        [] call FADE_troopInsertMissionMain;
    };
};
publicVariable "FADE_startTroopInsert";

// -----------------------------------------------------------------------------
// Map-click anchor: numeric [x,y] only (server).
// -----------------------------------------------------------------------------
FADE_fnc_isValidMapClickPos = {
    params ["_p"];
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { false };
    private _x = _p select 0;
    private _y = _p select 1;
    if (!(_x isEqualType 0) || {!(_y isEqualType 0)}) exitWith { false };
    true
};

// Map-click tier helpers: _radiusM < 0 = whole-map random (no anchor distance cap).
FADE_fnc_anchorWithinRadius = {
    params ["_pos", "_anchor", "_radiusM"];
    if (_radiusM < 0) exitWith { true };
    if (count _pos < 2 || { count _anchor < 2 }) exitWith { false };
    (_pos distance2D _anchor) <= _radiusM
};

// Map click ? nearest civ zone centre (eligible zones only: >= _minDistFromBase from HQ).
FADE_fnc_snapMapClickToNearestCivZone = {
    params ["_mapClick", ["_minDistFromBase", -1]];
    if (!([_mapClick] call FADE_fnc_isValidMapClickPos)) exitWith { [] };
    private _base = FADE_basePos;
    private _minDist = if (_minDistFromBase > 0) then { _minDistFromBase } else { FADE_minDistFromBase };
    private _best = [];
    private _bestD = 1e15;
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance _base) >= _minDist }) then {
                private _d = _zc distance2D _mapClick;
                if (_d < _bestD) then {
                    _bestD = _d;
                    _best = [(_zc select 0), (_zc select 1), (_zc param [2, 0])];
                };
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _best
};

// Built-up position near a civ zone centre (50�400 m by default).
FADE_fnc_urbanPosNearZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_innerMin", 50], ["_innerMax", 400]];
    if (count _zoneCenter < 2) exitWith { [] };
    private _base = FADE_basePos;
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _candidate = [[_zoneCenter, _innerMin, _innerMax, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
    if (count _candidate < 2 || { surfaceIsWater _candidate } || { (_candidate distance _base) < _minDist }) exitWith { [] };
    private _sx = _candidate select 0;
    private _sy = _candidate select 1;
    if (_sx < _minXY || { _sx > _maxXY } || { _sy < _minXY } || { _sy > _maxXY }) exitWith { [] };
    _candidate
};

FADE_fnc_tryHostageDestAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 450];
    if (({ count (_x buildingPos -1) >= 5 } count _buildings) < 2) exitWith { [] };
    _site
};

FADE_fnc_tryHvtDestAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 250];
    if (({ count (_x buildingPos -1) >= 10 } count _buildings) < 1) exitWith { [] };
    _site
};

FADE_fnc_trySearchDestroySiteAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_attempt", 1]];
    private _site = [_zoneCenter, _minDist, 40, _attempt] call FADE_fnc_posAtCivZoneCenter;
    private _buildings = nearestObjects [_zoneCenter, ["House", "Building"], 250];
    private _pickedTrial = [];
    {
        if (count _pickedTrial >= 3) exitWith {};
        if (count (_x buildingPos -1) >= 2) then { _pickedTrial pushBack _x };
    } forEach (_buildings call BIS_fnc_arrayShuffle);
    if (count _pickedTrial < 3) exitWith { [] };
    _site
};

FADE_fnc_assetPosAtZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_maxOffset", 80], ["_attempt", 1]];
    [_zoneCenter, _minDist, _maxOffset, _attempt] call FADE_fnc_posAtCivZoneCenter
};

// Dry land at civ zone centre (tight offset for map-click snap).
FADE_fnc_posAtCivZoneCenter = {
    params ["_zoneCenter", "_minDist", ["_maxOffset", 40], ["_attempt", 1]];
    if (count _zoneCenter < 2) exitWith { [] };
    private _innerMin = if (_attempt <= 1) then { 0 } else { 5 };
    private _innerMax = if (_attempt <= 1) then { _maxOffset } else { (_maxOffset + 40) min 80 };
    private _c = [_zoneCenter, _minDist, _innerMin, _innerMax] call FADE_fnc_urbanPosNearZoneCenter;
    if (count _c >= 2) then { _c } else { +_zoneCenter }
};

// One placement attempt at a snapped civ zone centre (map click).
FADE_fnc_pickDestAtCivZoneCenter = {
    params ["_missionType", "_minDistForPos", "_needsLZ", "_zoneCenter", ["_attempt", 1]];
    if (count _zoneCenter < 2) exitWith { [] };
    if (_missionType == "Hostage") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_tryHostageDestAtZoneCenter };
    if (_missionType == "HVT") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_tryHvtDestAtZoneCenter };
    if (_missionType == "SearchDestroy") exitWith { [_zoneCenter, _minDistForPos, _attempt] call FADE_fnc_trySearchDestroySiteAtZoneCenter };
    if (_missionType in ["AssetRetrieval", "MineClearing", "TroopExtract"]) exitWith {
        [_zoneCenter, _minDistForPos, 80, _attempt] call FADE_fnc_assetPosAtZoneCenter
    };
    if (_missionType in ["ClearArea", "AreaOfOperations"]) exitWith {
        [_zoneCenter, _minDistForPos, 40, _attempt] call FADE_fnc_posAtCivZoneCenter
    };
    if (_missionType == "Operation") exitWith { +_zoneCenter };
    private _candidate = [_zoneCenter, _minDistForPos, 50, 500] call FADE_fnc_urbanPosNearZoneCenter;
    if (count _candidate < 2) exitWith { [] };
    if (_needsLZ) then {
        private _lz = [_candidate] call FADE_findSafeLZ;
        if (count _lz < 2) exitWith { [] };
        _lz
    } else {
        _candidate
    }
};

FADE_fnc_tryHostageDestAtRadius = {
    params ["_anchor", "_minDist", "_radiusM"];
    private _buildRadius = 450;
    private _minSlots = 5;
    private _minBld = 2;
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _destPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrbanNearCenter
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearCenterNearAnchor
        };
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            private _candidates = _buildings select { count (_x buildingPos -1) >= _minSlots };
            if (count _candidates >= _minBld) then {
                private _center = getPosATL (_candidates select 0);
                if (_radiusM < 0 || { (_center distance2D _anchor) <= _radiusM }) then {
                    _result = _destPos;
                };
            };
        };
    };
    _result
};

FADE_fnc_tryHvtDestAtRadius = {
    params ["_anchor", "_minDist", "_radiusM", "_minSlots", "_buildRadius"];
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _destPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrban
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearAnchor
        };
        if (count _destPos >= 2) then {
            private _buildings = nearestObjects [_destPos, ["House", "Building"], _buildRadius];
            private _found = _buildings findIf { count (_x buildingPos -1) >= _minSlots };
            if (_found >= 0) then {
                private _center = getPosATL (_buildings select _found);
                if (_radiusM < 0 || { (_center distance2D _anchor) <= _radiusM }) then {
                    _result = [(_destPos select 0), (_destPos select 1), (_destPos param [2, 0])];
                };
            };
        };
    };
    _result
};

FADE_fnc_trySearchDestroySiteAtRadius = {
    params ["_anchor", "_minDist", "_radiusM"];
    private _areaRadius = 250;
    private _attempt = 0;
    private _result = [];
    while { _attempt < 20 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _tryPos = if (_radiusM < 0) then {
            [_minDist] call FADE_findMissionPosUrbanNearCenter
        } else {
            [_anchor, _minDist, _radiusM] call FADE_findMissionPosUrbanNearCenterNearAnchor
        };
        if (count _tryPos >= 2) then {
            private _c = +_tryPos;
            if (count _c < 3) then { _c = [(_c select 0), (_c select 1), 0] };
            private _buildings = nearestObjects [_c, ["House", "Building"], _areaRadius];
            private _cands = _buildings call BIS_fnc_arrayShuffle;
            private _pickedTrial = [];
            {
                if (count _pickedTrial >= 3) exitWith {};
                if (count (_x buildingPos -1) >= 2) then { _pickedTrial pushBack _x };
            } forEach _cands;
            if (count _pickedTrial >= 3) then {
                if (_radiusM < 0 || { (_c distance2D _anchor) <= _radiusM }) then {
                    _result = _c;
                };
            };
        };
    };
    _result
};

// One candidate at a fixed search radius from map click (server).
FADE_startMission_pickDestPosAtRadius = {
    params ["_missionType", "_minDistForPos", "_needsLZ", "_anchorPos", "_radiusM"];
    private _useAnchor = [_anchorPos] call FADE_fnc_isValidMapClickPos;
    if (_missionType == "InterceptConvoy") exitWith {
        if (_useAnchor) then {
            if (_radiusM < 0 || { [_anchorPos, _anchorPos, _radiusM] call FADE_fnc_anchorWithinRadius }) then { +_anchorPos } else { [] }
        } else { [0, 0, 0] }
    };
    if (_missionType == "Hostage") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrbanNearCenter };
        [_anchorPos, _minDistForPos, _radiusM] call FADE_fnc_tryHostageDestAtRadius
    };
    if (_missionType == "HVT") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrban };
        [_anchorPos, _minDistForPos, _radiusM, 10, 250] call FADE_fnc_tryHvtDestAtRadius
    };
    if (_missionType == "SearchDestroy") exitWith {
        if (!_useAnchor) exitWith { [_minDistForPos] call FADE_findMissionPosUrbanNearCenter };
        [_anchorPos, _minDistForPos, _radiusM] call FADE_fnc_trySearchDestroySiteAtRadius
    };
    if (_missionType == "Operation") exitWith {
        if (_useAnchor) then { +_anchorPos } else { +FADE_basePos }
    };
    if (_missionType == "TroopExtract") exitWith {
        if (_useAnchor) then {
            [_anchorPos, _minDistForPos, 500, _radiusM] call FADE_findMissionPosAssetRetrievalNearAnchor
        } else {
            [_minDistForPos, 500] call FADE_findMissionPosAssetRetrieval
        }
    };
    if (_missionType == "ClearArea" || { _missionType == "AreaOfOperations" }) exitWith {
        private _wholeR = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 5000];
        private _candidate = if (_useAnchor) then {
            if (_radiusM < 0) then {
                [_anchorPos, _minDistForPos, _wholeR] call FADE_findMissionPosNearAnchor
            } else {
                [_anchorPos, _minDistForPos, _radiusM] call FADE_findMissionPosNearAnchor
            }
        } else {
            [_minDistForPos] call FADE_findMissionPos
        };
        if (count _candidate >= 2) then { _candidate } else { [] }
    };
    if (_missionType == "AssetRetrieval" || { _missionType == "MineClearing" }) exitWith {
        if (_useAnchor) then {
            [_anchorPos, _minDistForPos, 500, _radiusM] call FADE_findMissionPosAssetRetrievalNearAnchor
        } else {
            [_minDistForPos, 500] call FADE_findMissionPosAssetRetrieval
        }
    };
    private _wholeR = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 5000];
    private _candidate = if (_useAnchor) then {
        if (_radiusM < 0) then {
            [_anchorPos, _minDistForPos, _wholeR] call FADE_findMissionPosNearAnchor
        } else {
            [_anchorPos, _minDistForPos, _radiusM] call FADE_findMissionPosNearAnchor
        }
    } else {
        [_minDistForPos] call FADE_findMissionPos
    };
    if (count _candidate < 2) exitWith { [] };
    if (_needsLZ) then {
        private _lz = [_candidate] call FADE_findSafeLZ;
        if (count _lz < 2) exitWith { [] };
        if (_useAnchor) then {
            private _lzR = if (_radiusM < 0) then { _wholeR } else { _radiusM };
            if (!([_lz, _anchorPos, _lzR] call FADE_fnc_anchorWithinRadius)) exitWith { [] };
        };
        _lz
    } else {
        _candidate
    }
};

// Returns [destPos, resolvedRadius, snappedZoneCenter]. resolvedRadius -2 = civ-zone snap (Config).
FADE_fnc_mapPickCandidatePasses = {
    params ["_candidate", "_missionType", "_pickupRef", "_minPickupDistM"];
    if (count _candidate < 2) exitWith { false };
    private _ok = _missionType in ["InterceptConvoy", "Operation", "AreaOfOperations"] || { [_candidate] call FADE_missionPosClear };
    if (!_ok) exitWith { false };
    if (_minPickupDistM >= 0 && { count _pickupRef >= 2 } && { (_candidate distance2D _pickupRef) < _minPickupDistM }) exitWith { false };
    true
};

// Map click: civ-zone missions snap to nearest settlement; others expand 250m -> whole map.
FADE_fnc_pickMissionDestNearMapClick = {
    params [
        "_anchor", "_missionType", "_minDistForPos", "_needsLZ",
        ["_pickupRef", []], ["_minPickupDistM", -1]
    ];
    private _snapTypes = missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []];
    if (_missionType in _snapTypes) then {
        private _zoneCenter = [_anchor, _minDistForPos] call FADE_fnc_snapMapClickToNearestCivZone;
        if (count _zoneCenter < 2) exitWith { [], -1, [] };
        private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
        private _result = [];
        for "_a" from 1 to 25 do {
            private _candidate = [_missionType, _minDistForPos, _needsLZ, _zoneCenter, _a] call FADE_fnc_pickDestAtCivZoneCenter;
            if (
                count _candidate >= 2
                && { [_candidate, _missionType, _pickupRef, _minPickupDistM] call FADE_fnc_mapPickCandidatePasses }
            ) then { _result = _candidate };
            if (count _result >= 2) exitWith {};
        };
        [_result, _snappedR, +_zoneCenter]
    } else {
        private _tiers = missionNamespace getVariable ["FADE_missionMapClickRadiusTiers", [250, 500, 1000, 2500, 5000, -1]];
        private _result = [];
        private _usedR = -1;
        {
            private _r = _x;
            for "_a" from 1 to 10 do {
                private _candidate = [_missionType, _minDistForPos, _needsLZ, _anchor, _r] call FADE_startMission_pickDestPosAtRadius;
                if (
                    count _candidate >= 2
                    && { [_candidate, _missionType, _pickupRef, _minPickupDistM] call FADE_fnc_mapPickCandidatePasses }
                ) then {
                    _result = _candidate;
                    _usedR = _r;
                };
                if (count _result >= 2) exitWith {};
            };
            if (count _result >= 2) exitWith {};
        } forEach _tiers;
        [_result, _usedR, []]
    };
};

// Troop Insert first LZ: shared tier search + pickup-distance filter (strict then relaxed).
FADE_fnc_pickTroopInsertLzNearMapClick = {
    params ["_lzAnchor", "_minDistForPos", "_pickupRef", "_lzMinStrict", "_lzMinRelaxed"];
    private _destPos = [];
    private _usedR = -1;
    private _snapped = [];
    for "_pass" from 0 to 1 do {
        private _needDist = if (_pass == 0) then { _lzMinStrict } else { _lzMinRelaxed };
        private _pick = [_lzAnchor, "TroopInsert", _minDistForPos, true, _pickupRef, _needDist] call FADE_fnc_pickMissionDestNearMapClick;
        _pick params ["_picked", "_r", "_snap"];
        if (count _picked >= 2) exitWith {
            _destPos = _picked;
            _usedR = _r;
            _snapped = _snap;
        };
    };
    [_destPos, _usedR, _snapped]
};

// Brief hint to mission starter after map-click placement resolves (grid + offset from click).
FADE_fnc_mapPickResultHint = {
    params ["_player", "_destPos", "_rawClick", "_snappedCenter", "_resolvedRadius"];
    if (isNull _player || { count _destPos < 2 }) exitWith {};
    private _grid = mapGridPosition _destPos;
    private _lines = [];
    private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
    if (count _snappedCenter >= 2 && { _resolvedRadius == _snappedR }) then {
        _lines pushBack format ["Snapped to nearest settlement (grid %1).", mapGridPosition _snappedCenter];
    };
    if (count _rawClick >= 2) then {
        private _d = round (_destPos distance2D _rawClick);
        if (_resolvedRadius >= 0) then {
            _lines pushBack format ["%1 m from your click (%2 m search tier).", _d, _resolvedRadius];
        } else {
            if (_resolvedRadius == _snappedR) then {
                _lines pushBack format ["%1 m from your click (settlement snap).", _d];
            } else {
                _lines pushBack format ["%1 m from your click.", _d];
            };
        };
    };
    private _detail = if (count _lines > 0) then { _lines joinString "<br/>" } else { "Loading mission details..." };
    [
        format [
            "<t size='1.1' color='#A0D0A0'>Mission area: grid %1</t><br/><t color='#808080'>%2</t>",
            _grid,
            _detail
        ]
    ] remoteExec ["FADE_showMissionHint", _player];
};

// -----------------------------------------------------------------------------
// One candidate anchor for FADE_startMission (server). Flat exitWith flow � avoids brittle nested if/else braces.
// -----------------------------------------------------------------------------
FADE_startMission_pickDestPos = {
    params ["_missionType", "_minDistForPos", "_needsLZ", ["_anchorPos", []], ["_radiusM", -1]];
    [_missionType, _minDistForPos, _needsLZ, _anchorPos, _radiusM] call FADE_startMission_pickDestPosAtRadius
};

// -----------------------------------------------------------------------------
// Start mission (server). Global: 1 at a time. Single: up to 3. Locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_startMission = {
    params ["_missionType", "_player", ["_anchorPos", []], ["_friendlyFaction", ""], ["_enemyFaction", ""], ["_civFaction", ""]];
    if (isNull _player) exitWith {};
    private _useMapAnchor = [_anchorPos] call FADE_fnc_isValidMapClickPos;
    if (_useMapAnchor && { surfaceIsWater _anchorPos }) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Invalid map location (water).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_missionType == "EscapeEvasion") exitWith {
        ["<t size='1.2' color='#FFAA00'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>Use START on this mission to open the evadee list (you must include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (_missionType == "TroopInsert") exitWith {
        ["<t size='1.2' color='#FFAA00'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Use START to open the participant list (pilots/drivers; include yourself).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (!([_player] call FADE_playerCanUseMissionsGui)) exitWith {
        ["<t size='1.2' color='#FF6666'>ACCESS DENIED</t><br/><br/><t color='#E0E0E0'>Missions GUI is restricted to group leaders by lobby settings.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    private _playerUid = getPlayerUID _player;
    private _isGlobal = _missionType in (missionNamespace getVariable ["FADE_globalMissionTypes", []]);
    private _isSingle = _missionType in (missionNamespace getVariable ["FADE_singleMissionTypes", []]);
    if (!_isGlobal && { !_isSingle }) exitWith {
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Unknown mission type.</t>"] ] remoteExec ["FADE_showMissionHint", _player];
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
    private _spawnsEnemies = _missionType in ["TroopExtract", "CAS", "HVT", "Hostage", "ClearArea", "InterceptConvoy", "AreaOfOperations", "CASEVAC", "CSAR", "AssetRetrieval", "SearchDestroy", "Operation", "EscapeEvasion"];
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
    if (_useMapAnchor) then {
        private _pick = [_anchorPos, _missionType, _minDistForPos, _needsLZ] call FADE_fnc_pickMissionDestNearMapClick;
        _pick params ["_picked", "_usedR", "_snapped"];
        _destPos = _picked;
        _mapPickRadius = _usedR;
        _snappedZone = _snapped;
    } else {
        while { _attempt < _maxAttempts } do {
            _attempt = _attempt + 1;
            _destPos = [_missionType, _minDistForPos, _needsLZ, []] call FADE_startMission_pickDestPos;
            if (count _destPos >= 2 && { _missionType == "InterceptConvoy" || { _missionType == "Operation" } || { [_destPos] call FADE_missionPosClear } }) exitWith {};
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
            if (_missionType == "AssetRetrieval" || { _missionType == "MineClearing" }) then {
                "NO SPOT NEAR A CIV ZONE WITHIN 500 M, OR ZONES TOO CLOSE TO BASE."
            } else {
                if (_missionType == "TroopExtract") then {
                    "NO TROOP EXTRACT PICKUP SPOT NEAR A CIV ZONE WITHIN 500 M."
                } else {
                    if (_needsLZ) then { "NO VALID LZ. CLEAR OF OBSTACLES REQUIRED. TRY AGAIN." } else { "NO VALID POSITION (or too close to other missions). TRY AGAIN." };
                };
            };
        };
        [format ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>%1%2</t>", _msg, _mapSuffix]] remoteExec ["FADE_showMissionHint", _player];
    };
    if (count _destPos >= 2 && { !([_destPos] call FADE_missionPosClear) } && { _missionType != "InterceptConvoy" } && { _missionType != "Operation" }) exitWith {
        ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No position at least 2 km from other missions. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };

    if (_useMapAnchor && { count _destPos >= 2 }) then {
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
    [_missionType, _destPos, _player, _useMapAnchor, _rawAnchor, _snappedZone, _mapPickRadius] spawn {
        params ["_missionType", "_destPos", "_player", "_useMapAnchor", "_rawAnchor", "_snappedZone", "_resolvedRadius"];
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
            [_rawAnchor, _anchor, _snappedZone, _resolvedRadius]
        ];
        [] call FADE_profile_missionStartMark;
        if (isNil "FADE_runMission") then { [] call FADE_installMissionModules };
        [] call FADE_runMission;
    };
};