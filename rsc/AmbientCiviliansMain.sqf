// AmbientCiviliansMain.sqf - zone poll loop and boot
// -----------------------------------------------------------------------------
// Main loop
// -----------------------------------------------------------------------------
FADE_civ_checkZones = {
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {};
    private _players = [];
    { if (alive _x && { isPlayer _x }) then { _players pushBack _x } } forEach allPlayers;
    if (_players isEqualTo []) exitWith {};
    [_players] call FADE_civ_cleanupDistantVehicles;
    call FADE_civ_ensurePinnedZonesSpawned;

    private _activateDist = missionNamespace getVariable ["FADE_civPlayerActivateDist", 800];
    private _deactivateDist = missionNamespace getVariable ["FADE_civPlayerDeactivateDist", 1200];
    private _zoneActivationDist = missionNamespace getVariable ["FADE_civZoneActivationDist", _activateDist];
    private _triggerNames = missionNamespace getVariable ["FADE_civTriggerNames", []];
    private _numPlayers = count _players;
    private _zoneKeys = keys FADE_civZoneState;

    for "_t" from 0 to (count _triggerNames - 1) do {
        private _name = _triggerNames select _t;
        private _trigger = missionNamespace getVariable [_name, objNull];
        if (!isNull _trigger) then {
            private _pinned = [_name] call FADE_civ_isZonePinned;
            private _center = getPosATL _trigger;
            private _minPlayerDist = 1e12;
            {
                _minPlayerDist = _minPlayerDist min (_x distance2D _center);
            } forEach _players;
            if (_minPlayerDist > _zoneActivationDist && { !_pinned }) then { continue };
            private _nearCount = 0;
            private _farCount = 0;
            for "_p" from 0 to (_numPlayers - 1) do {
                private _pl = _players select _p;
                if ((_pl distance _center) < _activateDist) then { _nearCount = _nearCount + 1 };
                if ((_pl distance _center) > _deactivateDist) then { _farCount = _farCount + 1 };
            };
            if (_nearCount > 0 || { _pinned }) then {
                private _alreadyActive = !(isNil { FADE_civZoneState get _name });
                private _maxZ = missionNamespace getVariable ["FADE_civMaxActiveZones", 4];
                if (!_alreadyActive && { !_pinned }) then {
                    private _guard = 0;
                    while { ([] call FADE_civ_countActiveNonPinnedZones) >= _maxZ && { _guard < 8 } } do {
                        _guard = _guard + 1;
                        private _evict = "";
                        private _evictScore = -1;
                        {
                            private _zid = _x;
                            if ([_zid] call FADE_civ_isZonePinned) then { continue };
                            private _zt = missionNamespace getVariable [_zid, objNull];
                            if (isNull _zt) then { continue };
                            private _zc = getPosATL _zt;
                            private _dClose = 1e12;
                            { _dClose = _dClose min (_zc distance2D _x) } forEach _players;
                            if (_dClose > _evictScore) then { _evictScore = _dClose; _evict = _zid };
                        } forEach _zoneKeys;
                        if (_evict == "") exitWith {};
                        [_evict] call FADE_civ_despawnZone;
                    };
                };
                if (_alreadyActive || { _pinned } || { ([] call FADE_civ_countActiveNonPinnedZones) < _maxZ }) then {
                    // #region agent log
                    if (random 1 < 0.12) then {
                        private _civN = count (call FADE_civ_getUnitClassesFromGui);
                        private _vehN = count (call FADE_civ_getVehicleClassesFromGui);
                        diag_log format [
                            "[FAC DbgBrowser 62d308] H26 civZoneActivate id=%1 near=%2 civClasses=%3 vehClasses=%4 enabled=%5",
                            _name, _nearCount, _civN, _vehN,
                            missionNamespace getVariable ["FADE_civiliansEnabled", true]
                        ];
                    };
                    // #endregion
                    [_trigger, _name] call FADE_civ_spawnZone;
                };
            };
            if (_farCount == _numPlayers && { !_pinned }) then { [_name] call FADE_civ_despawnZone };
        };
    };

    [_players] call FADE_civ_cullDistantFootGroups;
    [_players] call FADE_civ_enforceGlobalFootCap;

    private _validRoad = [];
    for "_i" from 0 to (count FADE_roadVehicles - 1) do {
        private _v = FADE_roadVehicles select _i;
        if (!isNull _v && { alive _v }) then { _validRoad pushBack _v };
    };
    FADE_roadVehicles = _validRoad;
};

// -----------------------------------------------------------------------------
// Start - reset hint flags when scenario settings applied (so re-apply can show hint again)
// -----------------------------------------------------------------------------
FADE_civ_resetHintFlags = {
    missionNamespace setVariable ["FADE_civNoCivsHintShown", false];
    missionNamespace setVariable ["FADE_civNoCivVehHintShown", false];
};

// -----------------------------------------------------------------------------
// Start
// -----------------------------------------------------------------------------
[] spawn {
    private _interval = missionNamespace getVariable ["FADE_civCheckInterval", 45];
    while { true } do {
        private _players = playableUnits select { alive _x && { isPlayer _x } };
        if (_players isEqualTo []) then {
            sleep 60;
        } else {
            sleep _interval;
            call FADE_civ_checkZones;
        };
    };
};

private _zoneCount = count (missionNamespace getVariable ["FADE_civTriggerNames", []]);
private _civClasses = call FADE_civ_getUnitClassesFromGui;
private _civVehClasses = call FADE_civ_getVehicleClassesFromGui;
private _factionStart = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
if (_zoneCount == 0) then {
    ["NO CIV ZONES BUILT (named locations + distance/water filter). Check FADE_basePos and FADE_civZone* Config."] call FADE_civ_debugChat;
} else {
    if (_civClasses isEqualTo [] && { _civVehClasses isEqualTo [] }) then {
        call FADE_civ_showNoCivsHint;
        call FADE_civ_showNoCivVehiclesHint;
        [format ["CIV POP: No civ units AND no civ vehicles for faction %1 - zone/road spawns disabled", _factionStart]] call FADE_civ_debugChat;
    } else {
        if (_civClasses isEqualTo []) then {
            call FADE_civ_showNoCivsHint;
            [format ["CIV POP: No civ units for faction %1 - zone spawns disabled, road vehicles need drivers", _factionStart]] call FADE_civ_debugChat;
        } else {
            if (_civVehClasses isEqualTo []) then {
                call FADE_civ_showNoCivVehiclesHint;
                [format ["CIV POP: %1 ZONES, faction %2 - zone spawns OK, no civ vehicles (road spawns disabled)", _zoneCount, _factionStart]] call FADE_civ_debugChat;
            } else {
                [format ["CIV POP: %1 ZONES, faction %2 - %3 unit types, %4 vehicle types (ambient road: ring around active zones)", _zoneCount, _factionStart, count _civClasses, count _civVehClasses]] call FADE_civ_debugChat;
            };
        };
    };
};

[] spawn {
    private _tick = missionNamespace getVariable ["FADE_roadSpawnTickSec", 60];
    private _chance = missionNamespace getVariable ["FADE_roadSpawnChance", 1];
    sleep _tick;
    while { true } do {
        if (
            (missionNamespace getVariable ["FADE_civiliansEnabled", true]) &&
            { count (keys FADE_civZoneState) > 0 } &&
            { random 1 < _chance }
        ) then {
            call FADE_civ_spawnRoadVehicle;
        };
        sleep _tick;
    };
};

[] spawn {
    private _intv = missionNamespace getVariable ["FADE_civCarRadioCheckInterval", 10];
    sleep _intv;
    while { true } do {
        call FADE_civ_tickCarRadios;
        sleep _intv;
    };
};

// -----------------------------------------------------------------------------
// Ambient civilian aircraft - fly past every ~10 minutes
// Spawns a civ aircraft at map edge, flies to the opposite edge, then despawns.
// Only runs if the civ faction has aircraft (scope >= 2, isKindOf "Air").
// -----------------------------------------------------------------------------
[] spawn {
    sleep 120;
    while { true } do {
        sleep (540 + random 120);
        if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) then { continue };
        private _faction = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
        if (_faction == "" || { isNil "FADE_getUnitsForFaction" }) then { continue };

        // Collect civ air classes from CfgVehicles: scope >= 2, Air, civ side (3) or faction matches
        private _civAir = [];
        {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            if (isClass _cfg && { getNumber (_cfg >> "scope") >= 2 } && { _x isKindOf "Air" }) then {
                private _side = getNumber (_cfg >> "side");
                private _fac = getText (_cfg >> "faction");
                if (_side == 3 || { _fac == _faction }) then { _civAir pushBack _x };
            };
        } forEach (keys FADE_civVehiclesByFaction);
        // Fall back to scanning known civ aircraft if map empty
        if (_civAir isEqualTo []) then {
            {
                private _cfg = configFile >> "CfgVehicles" >> _x;
                if (isClass _cfg && { getNumber (_cfg >> "scope") >= 2 } && { _x isKindOf "Air" } && { getNumber (_cfg >> "side") == 3 }) then { _civAir pushBack _x };
            } forEach ["C_Plane_Civil_01_F", "C_Plane_Civil_01_racing_F", "C_Helicopter_01_F"];
        };
        if (_civAir isEqualTo []) then { continue };

        private _aircraftClass = selectRandom _civAir;
        private _side = random 360;
        private _minX = missionNamespace getVariable ["FADE_mapMinX", missionNamespace getVariable ["FADE_mapMin", 0]];
        private _maxX = missionNamespace getVariable ["FADE_mapMaxX", missionNamespace getVariable ["FADE_mapMax", worldSize]];
        private _minY = missionNamespace getVariable ["FADE_mapMinY", missionNamespace getVariable ["FADE_mapMin", 0]];
        private _maxY = missionNamespace getVariable ["FADE_mapMaxY", missionNamespace getVariable ["FADE_mapMax", worldSize]];
        private _cx = (_minX + _maxX) / 2;
        private _cy = (_minY + _maxY) / 2;
        private _hx = (_maxX - _minX) / 2;
        private _hy = (_maxY - _minY) / 2;
        private _startEdge = [_cx + _hx * (sin _side) * 0.95, _cy + _hy * (cos _side) * 0.95, 180 + random 250];
        private _endEdge   = [_cx - _hx * (sin _side) * 0.95, _cy - _hy * (cos _side) * 0.95, _startEdge select 2];

        private _aircraft = createVehicle [_aircraftClass, _startEdge, [], 0, "FLY"];
        if (!isNull _aircraft) then {
            FADE_civAmbientAircraft pushBack _aircraft;
            _aircraft flyInHeight (180 + random 250);
            private _grp = createGroup civilian;
            private _driverCls = call FADE_civ_getUnitClassesFromGui;
            private _pilotCls = if (_driverCls isEqualTo []) then { "C_man_1" } else { selectRandom _driverCls };
            private _pilot = _grp createUnit [_pilotCls, _startEdge, [], 0, "NONE"];
            _pilot moveInDriver _aircraft;
            _pilot setVariable ["BIS_cp_excluded", true];
            _grp setVariable ["BIS_cp_excluded", true];
            _pilot setVariable ["FADE_ambientCiv", true];
            _aircraft setBehaviour "CARELESS";
            _aircraft setSpeedMode "FULL";
            private _wp = _grp addWaypoint [_endEdge, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointStatements ["true", "private _v = vehicle this; if (!isNil 'FADE_civAmbientAircraft') then { FADE_civAmbientAircraft = FADE_civAmbientAircraft - [_v] }; private _g = group this; { deleteVehicle _x } forEach units _g; deleteGroup _g; deleteVehicle _v;"];
            [format ["AMBIENT AIRCRAFT: %1 spawned", _aircraftClass]] call FADE_civ_debugChat;
        };
    };
};
