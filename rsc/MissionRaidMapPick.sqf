// =============================================================================
// MissionRaidMapPick.sqf  -  Raid: pick N objective zones on map (client)
// Start via execVM rsc\MissionRaidMapPick_exec.sqf
// Map stays open until all zones are placed; each must be >= 2 km from the others.
// =============================================================================
if (!hasInterface) exitWith {};

FAC_raidMapPick_fnc_zoneCount = {
    (round (missionNamespace getVariable ["FADE_raidObjectiveCount", 3])) max 2 min 5
};

FAC_raidMapPick_fnc_minSpacing = {
    missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000]
};

FAC_raidMapPick_fnc_clearMarkers = {
    private _n = [] call FAC_raidMapPick_fnc_zoneCount;
    for "_i" from 1 to _n do {
        private _m = format ["FAC_raidMapPick_%1", _i];
        if (markerShape _m != "") then { deleteMarker _m };
    };
};

FAC_raidMapPick_fnc_buildHint = {
    params ["_rem"];
    private _need = [] call FAC_raidMapPick_fnc_zoneCount;
    private _picked = +(missionNamespace getVariable ["FAC_raidMapPick_zones", []]);
    private _minD = [] call FAC_raidMapPick_fnc_minSpacing;
    private _n = count _picked;
    private _nextNum = _n + 1;
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    private _intro = [
        format ["Click the map for RAID objective %1 of %2.", _nextNum, _need],
        format ["Each zone must be at least %1 m from the others (snaps to nearest civ settlement on the server).", _minD]
    ];
    if (_n > 0) then {
        _intro pushBack format ["Placed: %1", (_picked apply { mapGridPosition _x }) joinString ", "];
    };
    [_rem, _intro, "", _timeout] call FADE_mapPick_formatCountdownHint
};

FAC_raidMapPick_fnc_disarm = {
    onMapSingleClick (str false);
    missionNamespace setVariable ["FAC_raidMapPick_active", false];
};

FAC_raidMapPick_fnc_finish = {
    params ["_timedOut"];
    [] call FAC_raidMapPick_fnc_disarm;
    [] call FAC_raidMapPick_fnc_clearMarkers;
    missionNamespace setVariable ["FAC_raidMapPick_zones", nil];
    if (visibleMap) then { openMap false };
    if (_timedOut) then {
        hint "Raid zone pick cancelled — not all objectives were placed.";
        systemChat "Raid zone pick cancelled — not all objectives were placed.";
    };
};

FAC_raidMapPick_fnc_arm = {
    if (!isNil "FADE_mapClickPick_clearHandler") then { [] call FADE_mapClickPick_clearHandler };
    // onMapSingleClick handler must return BOOL (see TeleportMapPick.sqf / FADE_mapClickPick_onMapClick).
    onMapSingleClick "missionNamespace setVariable ['FAC_raidMapPick_clickPos', _pos]; call FAC_raidMapPick_fnc_onClick; true;";
    // #region agent log
    diag_log format ["#DBGa783a2 {""sessionId"":""a783a2"",""hypothesisId"":""H1"",""location"":""MissionRaidMapPick.sqf:arm"",""message"":""raid map pick handler armed"",""data"":{},""timestamp"":%1}", diag_tickTime];
    // #endregion
};

FAC_raidMapPick_fnc_onClick = {
    if (!(missionNamespace getVariable ["FAC_raidMapPick_active", false])) exitWith { false };
    private _pos = missionNamespace getVariable ["FAC_raidMapPick_clickPos", []];
    // #region agent log
    diag_log format ["#DBGa783a2 {""sessionId"":""a783a2"",""hypothesisId"":""H1"",""location"":""MissionRaidMapPick.sqf:onClick"",""message"":""raid map click"",""data"":{""pickedSoFar"":%1,""clickPos"":%2},""timestamp"":%3}", count (missionNamespace getVariable ["FAC_raidMapPick_zones", []]), _pos, diag_tickTime];
    // #endregion
    private _parseFn = missionNamespace getVariable ["FADE_mapClickPick_parsePos", { [] }];
    private _clickPos = [[], _pos, false, false] call _parseFn;
    if (count _clickPos < 2) exitWith { false };
    if (surfaceIsWater _clickPos) exitWith {
        if (!visibleMap) then { openMap true };
        hint "Cannot select water — pick again.";
        systemChat "Cannot select water — pick again.";
        false
    };

    private _picked = +(missionNamespace getVariable ["FAC_raidMapPick_zones", []]);
    private _minD = [] call FAC_raidMapPick_fnc_minSpacing;
    private _tooClose = false;
    {
        if ((_clickPos distance2D _x) < _minD) exitWith {
            _tooClose = true;
            if (!visibleMap) then { openMap true };
            hint format [
                "Too close to objective %1 (grid %2) — need at least %3 m between zones.",
                _forEachIndex + 1,
                mapGridPosition _x,
                _minD
            ];
            systemChat format [
                "RAID: too close to zone %1 — need %2 m separation.",
                _forEachIndex + 1,
                _minD
            ];
        };
    } forEach _picked;
    if (_tooClose) exitWith { false };

    _picked pushBack _clickPos;
    missionNamespace setVariable ["FAC_raidMapPick_zones", _picked];

    private _mName = format ["FAC_raidMapPick_%1", count _picked];
    private _m = createMarkerLocal [_mName, _clickPos];
    _m setMarkerTypeLocal "mil_dot";
    _m setMarkerColorLocal "ColorYellow";
    _m setMarkerTextLocal format ["RAID %1", count _picked];

    private _need = [] call FAC_raidMapPick_fnc_zoneCount;
    missionNamespace setVariable ["FAC_raidMapPick_deadline", time + (missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20])];

    if (count _picked < _need) then {
        if (!visibleMap) then { openMap true };
        hint ([-1] call FAC_raidMapPick_fnc_buildHint);
        true
    } else {
        [] call FAC_raidMapPick_fnc_disarm;
        if (visibleMap) then { openMap false };
        [] call FAC_raidMapPick_fnc_clearMarkers;
        private _zones = +_picked;
        missionNamespace setVariable ["FAC_raidMapPick_zones", nil];
        missionNamespace setVariable ["FAC_raidMapPick_active", false];
        // #region agent log
        diag_log format ["#DBGa783a2 {""sessionId"":""a783a2"",""hypothesisId"":""H2"",""location"":""MissionRaidMapPick.sqf:onClick"",""message"":""raid zones submitted"",""data"":{""zoneCount"":%1,""zones"":%2},""timestamp"":%3}", count _zones, _zones, diag_tickTime];
        // #endregion
        [_zones, player] spawn {
            params ["_zones", "_pl"];
            systemChat "RAID: Zones submitted — setting up mission, please wait...";
            ["Raid", _pl, [], "", "", "", [], _zones] remoteExec ["FADE_startMission", 2];
            hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
        };
        true
    };
};

FAC_raidMapPick_fnc_start = {
    if (missionNamespace getVariable ["FAC_raidMapPick_active", false]) exitWith {
        systemChat "MISSION: raid zone pick already in progress.";
    };
    if (missionNamespace getVariable ["FAC_missionMapPick_active", false]) exitWith {
        systemChat "MISSION: map location pick already in progress.";
    };
    if (missionNamespace getVariable ["FAC_convoyMapPick_active", false]) exitWith {
        systemChat "MISSION: convoy route pick already in progress.";
    };

    missionNamespace setVariable ["FAC_raidMapPick_zones", []];
    [] call FAC_raidMapPick_fnc_clearMarkers;
    missionNamespace setVariable ["FAC_raidMapPick_active", true];
    private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
    missionNamespace setVariable ["FAC_raidMapPick_deadline", time + _timeout];
    [] call FAC_raidMapPick_fnc_arm;
    openMap true;
    hint ([-1] call FAC_raidMapPick_fnc_buildHint);

    [_timeout] spawn {
        params ["_timeout"];
        while { missionNamespace getVariable ["FAC_raidMapPick_active", false] } do {
            private _deadline = missionNamespace getVariable ["FAC_raidMapPick_deadline", 0];
            private _rem = (ceil (_deadline - time)) max 0;
            if (_rem <= 0) exitWith { [true] call FAC_raidMapPick_fnc_finish };
            hint ([_rem] call FAC_raidMapPick_fnc_buildHint);
            sleep 1;
        };
    };
};

missionNamespace setVariable ["FAC_raidMapPick_fnc_zoneCount", FAC_raidMapPick_fnc_zoneCount];
missionNamespace setVariable ["FAC_raidMapPick_fnc_minSpacing", FAC_raidMapPick_fnc_minSpacing];
missionNamespace setVariable ["FAC_raidMapPick_fnc_clearMarkers", FAC_raidMapPick_fnc_clearMarkers];
missionNamespace setVariable ["FAC_raidMapPick_fnc_buildHint", FAC_raidMapPick_fnc_buildHint];
missionNamespace setVariable ["FAC_raidMapPick_fnc_disarm", FAC_raidMapPick_fnc_disarm];
missionNamespace setVariable ["FAC_raidMapPick_fnc_finish", FAC_raidMapPick_fnc_finish];
missionNamespace setVariable ["FAC_raidMapPick_fnc_arm", FAC_raidMapPick_fnc_arm];
missionNamespace setVariable ["FAC_raidMapPick_fnc_onClick", FAC_raidMapPick_fnc_onClick];
missionNamespace setVariable ["FAC_raidMapPick_fnc_start", FAC_raidMapPick_fnc_start];
