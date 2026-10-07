// ServerGameplayMissionsStart.sqf - mission type lists, troop/escape/geo starts
// =============================================================================
// ServerGameplayMissions.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// -----------------------------------------------------------------------------
// Mission streams: Global (1 at a time, heavy) vs Single (up to 3, lighter). All locations >= 2 km apart.
// -----------------------------------------------------------------------------
FADE_globalMissionTypes = ["AreaOfOperations", "Hostage", "HVT", "ClearArea", "CAS", "InterceptConvoy", "SearchDestroy", "Operation", "Raid", "Invasion", "AssetRetrieval", "CSAR", "EscapeEvasion", "GeoGuesser", "PointDefense"];
FADE_singleMissionTypes = ["TroopInsert", "TroopExtract", "Cargo", "MineClearing", "CASEVAC"];
// FADE_minDistBetweenMissions — ConfigClient.sqf (publicVariable for JIP)
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

// Notify other players (systemChat) when a mission starts. BI tasks are side-wide (see Missions.sqf FADE_mission_createTask).
FADE_notifyOthersMissionStarted = {
    params ["_player", "_missionDisplayName"];
    private _others = allPlayers select { !isNull _x && { _x != _player } };
    { [format ["%1 started %2 - check Tasks for the brief.", name _player, _missionDisplayName]] remoteExec ["systemChat", _x] } forEach _others;
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

// Friendly players for a UID list. Returns [players, missing].
// _rejectBlankUid: empty or non-string UID counts as missing before the lookup (Escape / Geo).
// _dedupe: drop later copies of the same UID (Escape / Geo). Troop transport keeps both off.
FADE_mission_playersFromUids = {
    params ["_uids", ["_rejectBlankUid", true], ["_dedupe", true]];
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _players = [];
    private _missing = false;
    {
        private _uid = _x;
        if (_rejectBlankUid && { !(_uid isEqualType "") || { _uid == "" } }) then { _missing = true };
        private _p = objNull;
        { if (getPlayerUID _x == _uid) exitWith { _p = _x } } forEach allPlayers;
        if (isNull _p || { !alive _p } || { !isPlayer _p } || { side group _p != _sideFriendly }) then {
            _missing = true;
        } else {
            _players pushBack _p;
        };
    } forEach _uids;
    if (_dedupe) then {
        private _seen = [];
        _players = _players select {
            private _u = getPlayerUID _x;
            if (_u in _seen) then { false } else { _seen pushBack _u; true };
        };
    };
    [_players, _missing]
};

// True when this start must stop. Hint text matches Escape, Geo, and troop transport.
// FADE_startMission uses FADE_missionSlotGateHint (different copy) and does not call this.
FADE_mission_rejectIfBusy = {
    params ["_player", ["_checkSingleSlots", false]];
    private _global = missionNamespace getVariable ["FADE_globalMission", []];
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
    if ((count _global >= 1 && { [_global, _player] call FADE_isMissionEntryOwnedByPlayer }) || { { [_x, _player] call FADE_isMissionEntryOwnedByPlayer } count _singleList > 0 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>You already have a mission. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
        true
    };
    if (count _global >= 1) exitWith {
        ["<t size='1.2' color='#FFAA00'>GLOBAL MISSION ACTIVE</t><br/><br/><t color='#E0E0E0'>A global mission is in progress. Abort it first to start another.</t>"] remoteExec ["FADE_showMissionHint", _player];
        true
    };
    if (_checkSingleSlots && { count _singleList >= 3 }) exitWith {
        ["<t size='1.2' color='#FFAA00'>SINGLE SLOTS FULL</t><br/><br/><t color='#E0E0E0'>Three single missions are active. Wait for one to finish.</t>"] remoteExec ["FADE_showMissionHint", _player];
        true
    };
    false
};

FADE_mission_assignGlobal = {
    params ["_missionType", "_player", "_pos", "_playerUid"];
    private _operationName = [] call FADE_generateOperationName;
    missionNamespace setVariable ["FADE_globalMission", [_missionType, _player, _pos, _playerUid, _operationName]];
    missionNamespace setVariable ["FADE_currentMissionType", _missionType];
    missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
    [] call FADE_missionSlots_publish;
};

// _existingList: pass the array already read by the caller (FADE_startMission). Otherwise read the live list.
FADE_mission_assignSingle = {
    params ["_missionType", "_player", "_pos", "_playerUid", ["_setCurrent", false], ["_existingList", ""]];
    private _operationName = [] call FADE_generateOperationName;
    private _singleList = if (_existingList isEqualType []) then {
        _existingList
    } else {
        missionNamespace getVariable ["FADE_singleMissions", []]
    };
    _singleList pushBack [_missionType, _player, _pos, _playerUid, _operationName];
    missionNamespace setVariable ["FADE_singleMissions", _singleList];
    if (_setCurrent) then {
        missionNamespace setVariable ["FADE_currentMissionType", _missionType];
        missionNamespace setVariable ["FADE_currentMissionPlayer", _player];
    };
    [] call FADE_missionSlots_publish;
};

// -----------------------------------------------------------------------------
// Escape & Evasion (server): _evadeeUids must include _player's UID. Picks civ zone >= 4 km from base; Missions.sqf handles spawn/QRF.
// -----------------------------------------------------------------------------
FADE_startEscapeEvasion = {
    params ["_evadeeUids", "_player"];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    if (!(_evadeeUids isEqualType [])) exitWith {
        [_player, "MISSION ERROR", "Invalid evadee list."] call FADE_missionErrorHint;
    };
    if !([_player] call FADE_mission_requireGuiAccess) exitWith {};
    private _playerUid = getPlayerUID _player;
    if !(_playerUid in _evadeeUids) exitWith {
        ["<t size='1.2' color='#FF6666'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>You must include yourself in the evadee list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if ([_player, false] call FADE_mission_rejectIfBusy) exitWith {};
    ([_evadeeUids, true, true] call FADE_mission_playersFromUids) params ["_evadees", "_missing"];
    if (_missing || { count _evadees == 0 }) exitWith {
        ["<t size='1.2' color='#FF6666'>ESCAPE &amp; EVASION</t><br/><br/><t color='#E0E0E0'>One or more selected players are unavailable (disconnect, dead, or wrong side).</t>"] remoteExec ["FADE_showMissionHint", _player];
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
    ["EscapeEvasion", _player, _zoneCenter, _playerUid] call FADE_mission_assignGlobal;
    ["EscapeEvasion", _zoneCenter, _player, _evadees] spawn {
        params ["_missionType", "_destPos", "_player", "_evadees"];
        FADE_missionParams = [_missionType, _destPos, _player, _evadees];
        [] call FADE_profile_missionStartMark;
        if (isNil "FADE_runMission") then { [] call FADE_installMissionModules };
        [] call FADE_runMission;
    };
};

// -----------------------------------------------------------------------------
// Geo-Guesser (server): participant UIDs, round time (30-600 s), difficulty.
// -----------------------------------------------------------------------------
FADE_startGeoGuesser = {
    params ["_participantUids", "_timeSec", "_difficulty", "_player"];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    if (!(_participantUids isEqualType [])) exitWith {
        [_player, "MISSION ERROR", "Invalid participant list."] call FADE_missionErrorHint;
    };
    if !([_player] call FADE_mission_requireGuiAccess) exitWith {};
    private _playerUid = getPlayerUID _player;
    if !(_playerUid in _participantUids) exitWith {
        ["<t size='1.2' color='#FF6666'>GEO-GUESSER</t><br/><br/><t color='#E0E0E0'>You must include yourself in the participant list.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if ([_player, false] call FADE_mission_rejectIfBusy) exitWith {};
    _timeSec = if (_timeSec isEqualType 0) then { round _timeSec max 30 min 600 } else { 60 };
    if !(_difficulty in ["Normal", "Hard", "Impossible"]) then { _difficulty = "Normal" };
    ([_participantUids, true, true] call FADE_mission_playersFromUids) params ["_participants", "_missing"];
    if (_missing || { count _participants == 0 }) exitWith {
        ["<t size='1.2' color='#FF6666'>GEO-GUESSER</t><br/><br/><t color='#E0E0E0'>One or more selected players are unavailable (disconnect, dead, or wrong side).</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    if (isNil "FADE_geoGuesser_pickDropPos") then { [] call FADE_installMissionModules };
    private _dropPos = [_difficulty] call FADE_geoGuesser_pickDropPos;
    if (count _dropPos < 2) exitWith {
        ["<t size='1.2' color='#FF6666'>GEO-GUESSER</t><br/><br/><t color='#E0E0E0'>Could not find a valid drop location. Try again.</t>"] remoteExec ["FADE_showMissionHint", _player];
    };
    ["GeoGuesser", _player, _dropPos, _playerUid] call FADE_mission_assignGlobal;
    missionNamespace setVariable ["FADE_ggRun_timeSec", _timeSec];
    missionNamespace setVariable ["FADE_ggRun_difficulty", _difficulty];
    ["GeoGuesser", _dropPos, _player, _participants] spawn {
        params ["_missionType", "_destPos", "_player", "_participants"];
        FADE_missionParams = [_missionType, _destPos, _player, _participants];
        [] call FADE_profile_missionStartMark;
        if (isNil "FADE_runMission") then { [] call FADE_installMissionModules };
        [] call FADE_runMission;
    };
};

// -----------------------------------------------------------------------------
// Point Defense (server): duration handoff then standard FADE_startMission path.
// -----------------------------------------------------------------------------
FADE_startPointDefense = {
    params ["_player", ["_anchorPos", []], ["_durationSec", -1]];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    private _minS = missionNamespace getVariable ["FADE_pointDefenseDurationMinSec", 300];
    private _maxS = missionNamespace getVariable ["FADE_pointDefenseDurationMaxSec", 2400];
    private _defS = missionNamespace getVariable ["FADE_pointDefenseDurationSec", 1200];
    if (!(_durationSec isEqualType 0) || { _durationSec < 0 }) then { _durationSec = _defS };
    _durationSec = (round _durationSec max _minS) min _maxS;
    missionNamespace setVariable ["FADE_pdRun_durationSec", _durationSec];
    ["PointDefense", _player, _anchorPos] call FADE_startMission;
};
publicVariable "FADE_startPointDefense";

// -----------------------------------------------------------------------------
// Troop Insert / Extract (server): participating UIDs + wave count 1-10.
// Heli sites: random eligible civ zone -> LZ within FADE_troopHeliSiteMaxDistFromCivZone (default 250 m).
// -----------------------------------------------------------------------------
FADE_startTroopTransport_resolveParticipants = {
    params ["_participantUids", "_player", "_missionLabel"];
    ([_participantUids, false, false] call FADE_mission_playersFromUids) params ["_participants", "_missing"];
    if (_missing || { count _participants == 0 }) exitWith {
        [format ["<t size='1.2' color='#FF6666'>%1</t><br/><br/><t color='#E0E0E0'>One or more selected players are unavailable.</t>", _missionLabel]] remoteExec ["FADE_showMissionHint", _player];
        []
    };
    private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
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
            "<t size='1.2' color='#FFAA00'>%1</t><br/><br/><t color='#E0E0E0'>%2 already has an active mission.</t>",
            _missionLabel,
            name _busyParticipant
        ]] remoteExec ["FADE_showMissionHint", _player];
        []
    };
    _participants
};

FADE_startTroopTransport_gateSlots = {
    params ["_player"];
    !([_player, true] call FADE_mission_rejectIfBusy)
};

FADE_startTroopTransport_clampWaves = {
    params [["_waveCount", 1]];
    if (!(_waveCount isEqualType 0)) then { _waveCount = 1 };
    (_waveCount max 1) min 10
};

// Shared Insert/Extract preamble. [] on reject, else [playerUid, waveCount, participants].
FADE_startTroopTransport_open = {
    params ["_participantUids", "_waveCount", "_player", "_missionLabel", "_selfMissingHtml"];
    if (!(_participantUids isEqualType [])) exitWith {
        [_player, "MISSION ERROR", "Invalid participant list."] call FADE_missionErrorHint;
        []
    };
    if !([_player] call FADE_mission_requireGuiAccess) exitWith { [] };
    private _playerUid = getPlayerUID _player;
    if !(_playerUid in _participantUids) exitWith {
        [_selfMissingHtml] remoteExec ["FADE_showMissionHint", _player];
        []
    };
    _waveCount = [_waveCount] call FADE_startTroopTransport_clampWaves;
    if !([_player] call FADE_startTroopTransport_gateSlots) exitWith { [] };
    private _participants = [_participantUids, _player, _missionLabel] call FADE_startTroopTransport_resolveParticipants;
    if (_participants isEqualTo []) exitWith { [] };
    [_playerUid, _waveCount, _participants]
};

FADE_startTroopInsert = {
    params ["_participantUids", "_waveCount", "_player", ["_mapAnchor", []]];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    private _opened = [
        _participantUids,
        _waveCount,
        _player,
        "TROOP INSERT",
        "<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>You must include yourself in the participating list.</t>"
    ] call FADE_startTroopTransport_open;
    if (_opened isEqualTo []) exitWith {};
    _opened params ["_playerUid", "_waveCount", "_participants"];
    private _minDistForPos = FADE_troopInsertExtractMinDistFromBase max FADE_minDistFromBase;
    private _lzMinFromPickup = FADE_troopInsertLzMinDistFromPickup;
    private _pickupRef = +FADE_basePos;
    if (count FADE_bSpPoints > 0) then {
        private _bSp = selectRandom FADE_bSpPoints;
        if (!isNull _bSp) then { _pickupRef = getPosATL _bSp };
    };
    private _useMapAnchor = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
    private _preferredZone = [];
    private _snappedZone = [];
    if (_useMapAnchor) then {
        _preferredZone = [_mapAnchor, _minDistForPos] call FADE_fnc_snapMapClickToNearestCivZone;
        _snappedZone = +_preferredZone;
    };
    private _destPos = [_minDistForPos, [], _preferredZone, _lzMinFromPickup, _pickupRef] call FADE_fnc_pickTroopHeliSiteAtCivZone;
    if (count _destPos < 2) exitWith {
        private _mapSuffix = if (_useMapAnchor) then {
            " NO VALID LZ NEAR YOUR MAP CLICK (civ zone / heli landing search) - TRY ANOTHER AREA OR USE RANDOM."
        } else { "" };
        [_player, "MISSION ERROR", format ["No valid insert LZ near a civ zone (heli landing required, clear of other missions).%1", _mapSuffix]] call FADE_missionErrorHint;
    };
    if (_useMapAnchor && { count _destPos >= 2 }) then {
        [_player, _destPos, _mapAnchor, _snappedZone, -2] call FADE_fnc_mapPickResultHint;
    };
    ["TroopInsert", _player, _destPos, _playerUid, true] call FADE_mission_assignSingle;
    ["TroopInsert", _destPos, _player, _participants, _waveCount] spawn {
        params ["_missionType", "_destPos", "_player", "_participants", "_waveCount"];
        if (isNil "FADE_troopInsertMissionMain") then { [] call FADE_installMissionModules };
        FADE_troopInsertParams = [_missionType, _destPos, _player, _participants, _waveCount];
        [] call FADE_troopInsertMissionMain;
    };
};
publicVariable "FADE_startTroopInsert";

FADE_startTroopExtract = {
    params ["_participantUids", "_waveCount", "_player", ["_mapAnchor", []]];
    if (!isServer) exitWith {};
    if (isNull _player) exitWith {};
    private _opened = [
        _participantUids,
        _waveCount,
        _player,
        "TROOP EXTRACT",
        "<t size='1.2' color='#FF6666'>TROOP EXTRACT</t><br/><br/><t color='#E0E0E0'>You must include yourself in the participating list.</t>"
    ] call FADE_startTroopTransport_open;
    if (_opened isEqualTo []) exitWith {};
    _opened params ["_playerUid", "_waveCount", "_participants"];
    private _minDistForPos = FADE_troopInsertExtractMinDistFromBase max 1000;
    private _useMapAnchor = [_mapAnchor] call FADE_fnc_isValidMapClickPos;
    private _preferredZone = [];
    private _snappedZone = [];
    if (_useMapAnchor) then {
        _preferredZone = [_mapAnchor, _minDistForPos] call FADE_fnc_snapMapClickToNearestCivZone;
        _snappedZone = +_preferredZone;
    };
    private _destPos = [_minDistForPos, [], _preferredZone] call FADE_fnc_pickTroopHeliSiteAtCivZone;
    if (count _destPos < 2) exitWith {
        private _mapSuffix = if (_useMapAnchor) then {
            " NO VALID PICKUP NEAR YOUR MAP CLICK (civ zone / heli landing search) - TRY ANOTHER AREA OR USE RANDOM."
        } else { "" };
        [_player, "MISSION ERROR", format ["No valid extract pickup near a civ zone (heli landing required, clear of other missions).%1", _mapSuffix]] call FADE_missionErrorHint;
    };
    if (_useMapAnchor && { count _destPos >= 2 }) then {
        [_player, _destPos, _mapAnchor, _snappedZone, -2] call FADE_fnc_mapPickResultHint;
    };
    ["TroopExtract", _player, _destPos, _playerUid, true] call FADE_mission_assignSingle;
    ["TroopExtract", _destPos, _player, _participants, _waveCount] spawn {
        params ["_missionType", "_destPos", "_player", "_participants", "_waveCount"];
        if (isNil "FADE_troopExtractMissionMain") then { [] call FADE_installMissionModules };
        FADE_troopExtractParams = [_missionType, _destPos, _player, _participants, _waveCount];
        [] call FADE_troopExtractMissionMain;
    };
};
publicVariable "FADE_startTroopExtract";

// -----------------------------------------------------------------------------
// Map-click anchor: numeric [x,y] only (server).
// -----------------------------------------------------------------------------
