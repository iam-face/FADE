// =============================================================================
// TroopInsertMission.sqf — multi-participant Troop Insert (server)
// FADE_troopInsertParams: [_missionType, _destPos, _player, _participants, _mode]
// =============================================================================
if (!isServer) exitWith {};
if (isNil "FADE_troopInsert_runTransport") then {
    call compile preprocessFileLineNumbers "rsc\TroopInsertTransport.sqf";
};
if (isNil "FADE_troopInsertParams" || { count FADE_troopInsertParams < 5 }) exitWith {};
FADE_troopInsertParams params ["_missionType", "_destPos", "_player", "_participants", "_mode"];
if (_missionType != "TroopInsert") exitWith {};
if (!(_participants isEqualType []) || { count _participants == 0 }) exitWith {};
if !(_mode in ["oneOff", "recurring"]) then { _mode = "oneOff" };

if (([] call FADE_resolveScenarioFriendlyUnits) isEqualTo []) exitWith {
    if (!isNull _player) then { [_player] call FADE_clearActiveMission };
    ["<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>No friendly units for the scenario faction. Apply scenario settings or pick a faction with infantry.</t>"] remoteExec ["FADE_showMissionHint", _player];
};
private _markerFriendly = missionNamespace getVariable ["FADE_markerColorFriendly", "ColorWEST"];
private _mkrJitter = missionNamespace getVariable ["FADE_jitterMarkerPos", { params [["_p", [0, 0, 0]]]; [_p] call FADE_normPos3 }];
private _taskId = "FADE_TroopInsert" + str (floor (time * 1000));
private _abortFlag = "FADE_troopInsertAborted_" + _taskId;
private _claimedVehKey = "FADE_troopInsert_claimedVehs_" + _taskId;
missionNamespace setVariable [_abortFlag, false];
missionNamespace setVariable [_claimedVehKey, [], true];

private _pickupMin = missionNamespace getVariable ["FADE_troopInsertPickupMinDist", 500];
private _pickupMax = missionNamespace getVariable ["FADE_troopInsertPickupMaxDist", 1000];
private _lzMinFromPickup = missionNamespace getVariable ["FADE_troopInsertLzMinDistFromPickup", 2500];
private _waveTimeout = missionNamespace getVariable ["FADE_troopInsertWaveTimeout", 620];

private _missionEnded = false;
private _pairs = [];
private _markerName = "";

private _fnc_deleteGroups = {
    params ["_groups"];
    {
        if (!isNull _x) then {
            _x setVariable ["FADE_troopInsertCleanupDone", true, true];
            { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_x getVariable ["FADE_irStrobes", []]);
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _x;
            deleteGroup _x;
        };
    } forEach _groups;
};

// Per-player local pickup markers: each entry is [_mkrName, _owner] so we can target the
// right client for cleanup. Markers are created on the owner's client via remoteExec.
private _pickupMarkers = [];
private _fnc_clearPickupMarkers = {
    {
        _x params ["_mkrName", "_owner"];
        if (!isNull _owner) then {
            [_mkrName] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _owner];
        };
    } forEach _pickupMarkers;
    _pickupMarkers = [];
};

private _fnc_deletePickupMarkerForOwner = {
    params ["_owner"];
    if (isNull _owner) exitWith {};
    private _kept = [];
    {
        _x params ["_mkrName", "_mkrOwner"];
        if (_mkrOwner isEqualTo _owner) then {
            [_mkrName] remoteExec ["FAC_troopInsertClient_deletePickupMarker", _owner];
        } else {
            _kept pushBack _x;
        };
    } forEach _pickupMarkers;
    _pickupMarkers = _kept;
};

private _fnc_createPickupMarker = {
    params ["_owner", "_pos", "_label"];
    if (isNull _owner) exitWith { "" };
    private _mkr = format ["FADE_ti_pick_%1_%2", _taskId, getPlayerUID _owner];
    private _labelOut = if (_label != "") then { _label } else { "Squad link-up" };
    [_mkr, _pos, _labelOut, _markerFriendly] remoteExec ["FAC_troopInsertClient_createPickupMarker", _owner];
    _pickupMarkers pushBack [_mkr, _owner];
    _mkr
};

private _fnc_compassSector = {
    params ["_from", "_to"];
    private _pFrom = if (_from isEqualType []) then { _from } else { getPosATL _from };
    private _pTo = if (_to isEqualType []) then { _to } else { getPosATL _to };
    private _sectors = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    private _bearing = _pFrom getDir _pTo;
    _sectors select ((round ((_bearing + 22.5) / 45)) % 8)
};

private _fnc_squadPickupSideChat = {
    params ["_grp", "_atPos"];
    if (isNull _grp || { count units _grp == 0 }) exitWith {};
    private _ldr = leader _grp;
    if (isNull _ldr || { !alive _ldr }) exitWith {};
    private _cs = _grp getVariable ["FADE_callsign", "Alpha 1-1"];
    [_ldr, format ["This is %1. We're holding at Grid %2, waiting for your pickup. Over.", _cs, mapGridPosition _atPos]] call FADE_aiSideChat;
};

private _fnc_positionsCentroid = {
    params ["_positions"];
    if (_positions isEqualTo []) exitWith { [0, 0, 0] };
    private _sx = 0; private _sy = 0;
    { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _positions;
    private _n = count _positions;
    [_sx / _n, _sy / _n, 0]
};

private _fnc_pickupPosNearParticipant = {
    params ["_participant", ["_minDist", -1], ["_maxDist", -1]];
    if (_minDist < 0) then { _minDist = _pickupMin };
    if (_maxDist < 0) then { _maxDist = _pickupMax };
    private _anchor = getPosATL _participant;
    private _pos = [];
    for "_try" from 0 to 18 do {
        private _dist = _minDist + random (_maxDist - _minDist);
        private _cand = [_anchor, _dist, random 360] call BIS_fnc_relPos;
        private _safe = [_cand, 0, 50, 6, 1, 0.4, 0, [], _cand] call BIS_fnc_findSafePos;
        if (_safe isEqualType [] && { count _safe >= 2 } && { !surfaceIsWater [_safe select 0, _safe select 1] }) exitWith { _pos = _safe };
    };
    if (count _pos < 2) then { _pos = [_anchor, (_minDist + _maxDist) / 2, random 360] call BIS_fnc_relPos };
    if (count _pos < 3) then { _pos set [2, 0] };
    _pos
};

private _fnc_findRecurringLz = {
    // Recurring waves only: random LZ within mission distance rules (never map-click anchor).
    params ["_pickupCentroid", "_prevLz", "_minDistFromBase"];
    private _lz = [];
    private _minFromPickup = _lzMinFromPickup;
    private _minFromPrev = _lzMinFromPickup;
    for "_pass" from 0 to 1 do {
        if (_pass == 1) then {
            _minFromPickup = (_lzMinFromPickup * 0.7) max 1500;
            _minFromPrev = 500;
        };
        for "_a" from 0 to 40 do {
            private _cand = [_minDistFromBase] call FADE_findMissionPos;
            if (count _cand >= 2) then {
                private _candLz = [_cand] call FADE_findSafeLZ;
                if (
                    count _candLz >= 2
                    && { [_candLz] call FADE_missionPosClear }
                    && { _candLz distance2D _pickupCentroid >= _minFromPickup }
                    && { _candLz distance2D _prevLz >= _minFromPrev }
                ) then {
                    _lz = _candLz;
                    break;
                };
            };
        };
        if (count _lz >= 2) exitWith {};
    };
    _lz
};

private _fnc_unitClassesForParticipant = {
    params ["_participant"];
    private _units = [] call FADE_resolveScenarioFriendlyUnits;
    if (isNull _participant || { !alive _participant }) exitWith { _units };
    private _cfgRoot = configFile >> "CfgVehicles";
    private _pFac = getText (_cfgRoot >> typeOf _participant >> "faction");
    if (_pFac == "") exitWith { _units };
    private _matched = _units select { getText (_cfgRoot >> _x >> "faction") == _pFac };
    if (count _matched > 0) then { _matched } else { _units }
};

private _fnc_spawnSquadForParticipant = {
    params ["_participant", "_atPos"];
    private _unitCount = 6;
    if (!isNull _participant) then {
        private _veh = vehicle _participant;
        if (_veh != _participant && { _veh isKindOf "Helicopter" }) then {
            _unitCount = ([_veh] call FADE_getCargoSeats) max 1;
        };
    };
    private _friendlyUnits = [_participant] call _fnc_unitClassesForParticipant;
    if (_friendlyUnits isEqualTo []) exitWith { grpNull };
    private _sideFriendly = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _classes = (_friendlyUnits select [0, _unitCount min count _friendlyUnits]);
    private _baseClass = _friendlyUnits select 0;
    for "_i" from (count _classes) to (_unitCount - 1) do { _classes pushBack _baseClass };
    private _grp = [_atPos, _sideFriendly, _classes] call BIS_fnc_spawnGroup;
    [_grp] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_grp] call (missionNamespace getVariable ["FADE_attachNightStrobes", {}]);
    _grp setBehaviour "SAFE";
    _grp setCombatMode "GREEN";
    _grp setVariable ["FADE_troopInsertOwner", _participant, true];
    [_taskId, _grp] call FADE_missionEnt_registerGroup;
    [_grp, _atPos] call _fnc_squadPickupSideChat;
    if (!isNull _participant && { alive _participant }) then {
        private _distHint = "";
        private _pPos = getPosATL _participant;
        private _distVal = _pPos distance2D _atPos;
        if (_distVal > 200) then {
            private _dist = round _distVal;
            private _sector = [_pPos, _atPos] call _fnc_compassSector;
            _distHint = format [" Approx %1 m %2 from your position.", _dist, _sector];
        };
        [format [
            "<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>%1 link-up: Grid %2.%3 Board as driver or commander within 200 m.</t>",
            _grp getVariable ["FADE_callsign", "Your squad"],
            mapGridPosition _atPos,
            _distHint
        ]] remoteExec ["FADE_showMissionHint", _participant];
    };
    _grp
};

private _fnc_runTransportWave = {
    params ["_pairs", ["_defaultPickup", [0, 0, 0]], "_drop"];
    if (_missionEnded) exitWith { [] };
    private _runFn = missionNamespace getVariable ["FADE_troopInsert_runTransport", nil];
    if (isNil "_runFn") exitWith { [] };
    missionNamespace setVariable [_claimedVehKey, [], true];
    private _scripts = [];
    private _waveStart = time;
    {
        _x params ["_grp", "_owner", ["_pick", []], ["_pickMkr", ""]];
        private _pickupPos = if (count _pick >= 2) then { _pick } else { _defaultPickup };
        if (!isNull _grp && { count units _grp > 0 }) then {
            _grp setVariable ["FADE_troopInsertTransportDone", false, true];
            private _scr = [_grp, _owner, _pickupPos, _drop, _taskId, _markerName, _abortFlag, _claimedVehKey, _pickMkr] spawn _runFn;
            _scripts pushBack [_scr, _grp, _owner];
        };
    } forEach _pairs;
    if (count _scripts == 0) exitWith { _scripts };
    waitUntil {
        sleep 2;
        if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith { true };
        ({ scriptDone (_x select 0) } count _scripts) == count _scripts || { time - _waveStart > _waveTimeout }
    };
    {
        _x params ["_grp", "_owner"];
        if (!isNull _grp && { !(_grp getVariable ["FADE_troopInsertTransportDone", false]) }) then {
            if !(_grp getVariable ["FADE_troopInsertCleanupDone", false]) then {
                { if (!isNull _x) then { detach _x; deleteVehicle _x } } forEach (_grp getVariable ["FADE_irStrobes", []]);
                { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
                deleteGroup _grp;
            };
            if (!isNull _owner) then {
                ["<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Your squad transport failed or timed out.</t>"] remoteExec ["FADE_showMissionHint", _owner];
            };
        };
    } forEach (_scripts apply { [_x select 1, _x select 2] });
    _scripts
};

private _fnc_finishMission = {
    params [
        ["_taskState", ""],
        ["_hint", ""],
        ["_hintAllParticipants", true]
    ];
    if (_missionEnded) exitWith {};
    _missionEnded = true;
    missionNamespace setVariable [_abortFlag, true, true];

    if (_taskState != "") then { [_taskId, _taskState] call BIS_fnc_taskSetState };

    if (_hint != "") then {
        private _hintFormatted = if ((count _hint > 0) && { _hint select 0 == "<" }) then { _hint } else {
            format ["<t color='#E0E0E0'>%1</t>", _hint]
        };
        if (_hintAllParticipants) then {
            { [_hintFormatted] remoteExec ["FADE_showMissionHint", _x] } forEach _participants;
        } else {
            if (!isNull _player) then { [_hintFormatted] remoteExec ["FADE_showMissionHint", _player] };
        };
    };

    [_pairs apply { _x select 0 }] call _fnc_deleteGroups;
    [] call _fnc_clearPickupMarkers;
    if (_markerName != "") then { [_markerName] call FADE_deleteMarkerSafe };
    if (_taskId != "") then { [_taskId, "TroopInsert", false] call FADE_cleanupMissionEntities };

    {
        if (!isNull _x) then {
            _x setVariable ["FADE_myMission", "", true];
            _x setVariable ["FADE_myMissionTaskId", nil, true];
            _x setVariable ["FADE_myMissionMarker", nil, true];
            _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
            _x setVariable ["FADE_myMissionBrief", nil, true];
        };
    } forEach _participants;

    if (!isNull _player) then { [_player, _taskId] call FADE_clearActiveMission };
    missionNamespace setVariable [_abortFlag, nil];
    missionNamespace setVariable [_claimedVehKey, nil, true];
    missionNamespace setVariable ["FADE_currentMissionType", ""];
    missionNamespace setVariable ["FADE_currentMissionPlayer", objNull];
    publicVariable "FADE_currentMissionType";
};

private _fnc_waveAllTransportOk = {
    params ["_pairList"];
    if (_pairList isEqualTo []) exitWith { false };
    private _ok = true;
    {
        private _g = _x select 0;
        if (isNull _g || { !(_g getVariable ["FADE_troopInsertTransportDone", false]) }) then { _ok = false };
    } forEach _pairList;
    _ok
};

private _fnc_liveParticipants = {
    private _live = [];
    { if (!isNull _x && { alive _x }) then { _live pushBack _x } } forEach _participants;
    _live
};

// --- Mission setup ---
if (!isNull _player) then {
    _player setVariable ["FADE_myMission", "TroopInsert", true];
    _player setVariable ["FADE_myMissionTaskId", _taskId, true];
};
{
    if (!isNull _x && { _x != _player }) then {
        _x setVariable ["FADE_myMission", "TroopInsert", true];
        _x setVariable ["FADE_myMissionTaskId", _taskId, true];
    };
} forEach _participants;

[_taskId] call FADE_missionEnt_init;

private _operationName = "Operation Iron Resolve";
private _playerUid = if (isNull _player) then { "" } else { getPlayerUID _player };
private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
private _singleIdx = _singleList findIf {
    (_x param [0, ""]) == "TroopInsert" && { (_x param [3, ""]) == _playerUid }
};
if (_singleIdx >= 0) then { _operationName = (_singleList select _singleIdx) param [4, _operationName] };

_markerName = "FADE_insert_" + _taskId;
private _dropPos = +_destPos;
private _modeLabel = if (_mode == "recurring") then { "Recurring" } else { "One-Off" };

private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
private _taskDesc = format [
    "Insert friendly squads at the marked LZ. Participating transports: %1. Mode: %2. One distinct vehicle per pilot; pickup as driver/commander.",
    count _participants,
    _modeLabel
];
[_sf, _taskId, [_taskDesc, "Troop Insert", ""], _dropPos, "CREATED", 1, true, "move", true] call BIS_fnc_taskCreate;

{
    if (!isNull _x) then { _x setVariable ["FADE_myMissionMarker", _markerName, true] };
} forEach _participants;
private _marker = createMarker [_markerName, [_dropPos, 100] call _mkrJitter];
[_taskId, _markerName] call FADE_missionEnt_registerMarker;
_marker setMarkerType "mil_pickup";
_marker setMarkerColor _markerFriendly;
_marker setMarkerText _operationName;

private _grid = mapGridPosition _dropPos;
private _brief = format [
    "TROOP INSERT (%1)%2%2LZ (approx.): Grid %3%2%2Multi-transport insert. %4 participating pilot(s)/driver(s). Mode: %1.",
    _modeLabel, toString [10], _grid, count _participants
];
if (!isNull _player) then { _player setVariable ["FADE_myMissionBrief", _brief, true] };
{
    [format [
        "<t color='#FFFFFF'>LZ Grid: %1</t><br/><br/><t color='#FFFFFF'>Mode: %2 | %3 transport(s). Pick up squads and insert at the LZ.</t>",
        _grid, _modeLabel, count _participants
    ]] remoteExec ["FADE_showMissionHint", _x];
} forEach _participants;
if (!isNull _player) then { [_player, "Troop Insert"] call FADE_notifyOthersMissionStarted };

// Initial wave: spawn each squad at a base spawn point (B_SP_*) so the player can
// link up at base. Fallback chain: nearest free B_SP -> FADE_basePos -> per-participant offset.
private _bSpPool = +(missionNamespace getVariable ["FADE_bSpPoints", []]);
private _basePosInit = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
_pairs = [];
{
    if (!isNull _x && { alive _x }) then {
        private _pickPos = [];
        if (count _bSpPool > 0) then {
            private _bsp = [_bSpPool, _x] call BIS_fnc_nearestPosition;
            if (!isNull _bsp) then {
                _bSpPool = _bSpPool - [_bsp];
                _pickPos = getPosATL _bsp;
            };
        };
        if (count _pickPos < 2 && { count _basePosInit >= 2 }) then {
            _pickPos = +_basePosInit;
        };
        if (count _pickPos < 2) then {
            _pickPos = [_x, _pickupMin, _pickupMax] call _fnc_pickupPosNearParticipant;
        };
        private _grp = [_x, _pickPos] call _fnc_spawnSquadForParticipant;
        if (!isNull _grp) then {
            private _cs = _grp getVariable ["FADE_callsign", "Squad"];
            private _pickMkr = [_x, _pickPos, _cs] call _fnc_createPickupMarker;
            _pairs pushBack [_grp, _x, _pickPos, _pickMkr];
        };
    };
} forEach _participants;

if (_pairs isEqualTo []) then {
    ["FAILED", "<t size='1.2' color='#FF6666'>MISSION ERROR</t><br/><br/><t color='#E0E0E0'>Could not spawn squads (check scenario friendly units).</t>", true] call _fnc_finishMission;
};
if (_missionEnded) exitWith {};

private _pickPositions = _pairs apply { _x select 2 };
private _basePickup = if (_pickPositions isEqualTo []) then {
    missionNamespace getVariable ["FADE_basePos", [0, 0, 0]]
} else {
    [_pickPositions] call _fnc_positionsCentroid
};
[_pairs, _basePickup, _dropPos] call _fnc_runTransportWave;

if (_missionEnded) exitWith {};

if (missionNamespace getVariable [_abortFlag, false]) then {
    ["CANCELED", "<t size='1.2' color='#B0B0B0'>MISSION ABORTED</t><br/><br/><t color='#E0E0E0'>Mission cancelled.</t>", true] call _fnc_finishMission;
};
if (_missionEnded) exitWith {};

if (_mode == "oneOff") then {
    if ([_pairs] call _fnc_waveAllTransportOk) then {
        ["SUCCEEDED", "<t size='1.2' color='#90EE90'>TROOP INSERT COMPLETE</t><br/><br/><t color='#E0E0E0'>All squads inserted at the LZ.</t>", true] call _fnc_finishMission;
    } else {
        ["FAILED", "<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>One or more squads failed to insert.</t>", true] call _fnc_finishMission;
    };
} else {
    while { !_missionEnded && { !(missionNamespace getVariable [_abortFlag, false]) } } do {
        if !([_pairs] call _fnc_waveAllTransportOk) then {
            ["FAILED", "<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>A squad transport failed. Mission ended.</t>", true] call _fnc_finishMission;
        };
        if (_missionEnded) exitWith {};

        private _liveParticipants = [] call _fnc_liveParticipants;
        if (_liveParticipants isEqualTo []) then {
            ["SUCCEEDED", "<t size='1.2' color='#FFAA66'>TROOP INSERT ENDED</t><br/><br/><t color='#E0E0E0'>All participating players left or were killed.</t>", true] call _fnc_finishMission;
        };
        if (_missionEnded) exitWith {};

        private _reinfDelay = 10;
        private _minDist = FADE_troopInsertExtractMinDistFromBase max 2000;
        private _prevLz = +_dropPos;

        // Shared link-up: pick ONE safe pickup anchor ~ pickupMin..pickupMax from the
        // centroid of all live participants. All squads gather here, all pilots fly here
        // together. This replaces the previous per-participant random pickup so flights
        // can stay in formation.
        private _centroidParticipants = [_liveParticipants apply { getPosATL _x }] call _fnc_positionsCentroid;
        private _sharedPickup = [];
        for "_try" from 0 to 24 do {
            private _dist = _pickupMin + random (_pickupMax - _pickupMin);
            private _cand = [_centroidParticipants, _dist, random 360] call BIS_fnc_relPos;
            private _safe = [_cand, 0, 80, 8, 1, 0.4, 0, [], _cand] call BIS_fnc_findSafePos;
            if (_safe isEqualType [] && { count _safe >= 2 } && { !surfaceIsWater [_safe select 0, _safe select 1] }) exitWith { _sharedPickup = _safe };
        };
        if (count _sharedPickup < 2) then {
            _sharedPickup = [_centroidParticipants, (_pickupMin + _pickupMax) / 2, random 360] call BIS_fnc_relPos;
        };
        if (count _sharedPickup < 3) then { _sharedPickup set [2, 0] };

        private _newLz = [_sharedPickup, _prevLz, _minDist] call _fnc_findRecurringLz;
        if (count _newLz < 2) then {
            ["SUCCEEDED", "<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>No valid LZ at least 2.5 km from link-up. Mission ended.</t>", true] call _fnc_finishMission;
        };
        if (_missionEnded) exitWith {};

        private _nextLzGrid = mapGridPosition _newLz;
        [] call _fnc_clearPickupMarkers;
        _pairs = [];
        private _liveCount = count _liveParticipants;
        private _spawnJitterR = if (_liveCount <= 1) then { 0 } else { 25 };
        {
            // Stagger spawn points in a small ring around the shared anchor so squads
            // do not stack on top of each other. The pickup position passed to the
            // transport remains the shared anchor for every pilot.
            private _angle = (_forEachIndex * (360 / (_liveCount max 1))) + (random 20);
            private _spawnPos = [_sharedPickup, _spawnJitterR, _angle] call BIS_fnc_relPos;
            if (count _spawnPos < 3) then { _spawnPos set [2, 0] };
            private _grp = [_x, _spawnPos] call _fnc_spawnSquadForParticipant;
            if (!isNull _grp) then {
                private _cs = _grp getVariable ["FADE_callsign", "Squad"];
                private _pickMkr = [_x, _sharedPickup, _cs] call _fnc_createPickupMarker;
                _pairs pushBack [_grp, _x, _sharedPickup, _pickMkr];
            };
        } forEach _liveParticipants;

        if (_pairs isEqualTo []) then {
            ["FAILED", "<t size='1.2' color='#FF6666'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Could not spawn reinforcement squads.</t>", true] call _fnc_finishMission;
        };
        if (_missionEnded) exitWith {};

        private _sharedGrid = mapGridPosition _sharedPickup;
        private _sharedLzKm = (round ((_newLz distance2D _sharedPickup) / 100)) / 10;
        {
            _x params ["_grp", "_owner", "_pickPos"];
            if (!isNull _owner && { alive _owner }) then {
                private _dist = round ((getPosATL _owner) distance2D _pickPos);
                private _sector = [getPosATL _owner, _pickPos] call _fnc_compassSector;
                [format [
                    "<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Shared link-up at Grid %1 — approx %2 m %3 from you. All pilots converge here, pick up within %4 s, then insert at LZ Grid %5 (approx %6 km from link-up).</t>",
                    _sharedGrid, _dist, _sector, _reinfDelay, _nextLzGrid, _sharedLzKm
                ]] remoteExec ["FADE_showMissionHint", _owner];
            };
        } forEach _pairs;

        for "_sec" from 1 to _reinfDelay do {
            if (_missionEnded || { missionNamespace getVariable [_abortFlag, false] }) exitWith {};
            if (_sec == 5) then {
                {
                    _x params ["_grp", "_owner", "_pickPos"];
                    [_grp, _pickPos] call _fnc_squadPickupSideChat;
                    if (!isNull _owner && { alive _owner }) then {
                        private _lzKm = (round ((_newLz distance2D _pickPos) / 100)) / 10;
                        [format [
                            "<t color='#FFFFFF'>TROOP INSERT</t><br/><br/><t color='#E0E0E0'>Still holding at Grid %1 — link up in %2 s. Insert LZ Grid %3 (%4 km from link-up).</t>",
                            mapGridPosition _pickPos, _reinfDelay - _sec, _nextLzGrid, _lzKm
                        ]] remoteExec ["FADE_showMissionHint", _owner];
                    };
                } forEach _pairs;
            };
            sleep 1;
        };
        if (_missionEnded) exitWith {};

        _dropPos = _newLz;
        private _mkPos = [_dropPos, 100] call _mkrJitter;
        _marker setMarkerPos _mkPos;
        [_taskId, _dropPos] call BIS_fnc_taskSetDestination;
        [_pairs, [0, 0, 0], _dropPos] call _fnc_runTransportWave;
    };
    if (!_missionEnded && { !(missionNamespace getVariable [_abortFlag, false]) }) then {
        ["SUCCEEDED", "<t size='1.2' color='#90EE90'>TROOP INSERT COMPLETE</t><br/><br/><t color='#E0E0E0'>Recurring Troop Insert ended.</t>", true] call _fnc_finishMission;
    };
};
