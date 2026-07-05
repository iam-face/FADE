// =============================================================================
// ServerGameplayVehicles.sqf — extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

// Client Vehicle GUI sends netId strings (reliable MP); legacy object refs still accepted.
FADE_fnc_vehicleFromRpcParam = {
    params ["_vehParam"];
    if (_vehParam isEqualType objNull) exitWith { _vehParam };
    if !(_vehParam isEqualType "") exitWith { objNull };
    if (_vehParam == "") exitWith { objNull };
    private _veh = objectFromNetId _vehParam;
    if (isNull _veh) then { _veh = _vehParam call BIS_fnc_objectFromNetId };
    _veh
};

// -----------------------------------------------------------------------------
// Spawn helicopter (server). Called via remoteExec from client Vehicle GUI.
// Validates class and pad availability; creates vehicle on server; feedback via remoteExec to _player.
// -----------------------------------------------------------------------------
FADE_spawnHeli = {
    params ["_heliClass", "_player", ["_padIndex", -1]];
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNil "_heliClass" || { _heliClass == "" }) exitWith {
        ["INVALID AIRCRAFT CLASS."] remoteExec ["systemChat", _player];
    };
    if (count FADE_helipadList == 0) exitWith {
        ["NO PADS AVAILABLE."] remoteExec ["systemChat", _player];
    };

    // Planes cannot spawn at FADE_planeForbiddenPads; helicopters can use any pad
    private _isPlane = _heliClass isKindOf "Plane";
    private _forbidden = missionNamespace getVariable ["FADE_planeForbiddenPads", []];
    private _candidatePads = FADE_helipadList select {
        if (_isPlane) then { !((_x select 1) in _forbidden) } else { true }
    };

    private _pad = objNull;
    private _padRadius = 10;
    private _fnc_padBlocking = {
        params ["_padObj"];
        private _pos = getPosATL _padObj;
        private _near = nearestObjects [_pos, ["Air", "LandVehicle"], _padRadius];
        _near select { !isNull _x && { alive _x } }
    };

    // Optional: spawn on a specific helipad index (Vehicle GUI); -1 = first free among candidates
    if (_padIndex >= 0 && {_padIndex < count FADE_helipadList}) then {
        private _entry = FADE_helipadList select _padIndex;
        _entry params ["_padObj", "_padName"];
        if (_isPlane && {_padName in _forbidden}) exitWith {
            [format ["PLANES CANNOT SPAWN AT %1.", _padName]] remoteExec ["systemChat", _player];
        };
        if (count ([_padObj] call _fnc_padBlocking) > 0) exitWith {
            ["SELECTED PAD IS OCCUPIED."] remoteExec ["systemChat", _player];
        };
        _pad = _padObj;
    } else {
        {
            _x params ["_padObj", "_padName"];
            if (count ([_padObj] call _fnc_padBlocking) == 0) exitWith { _pad = _padObj };
        } forEach _candidatePads;
    };
    if (isNull _pad) exitWith {
        ["ALL PADS OCCUPIED. DESPAWN OR MOVE AIRCRAFT 10M+ FROM PAD."] remoteExec ["systemChat", _player];
    };
    private _pos = getPosATL _pad;
    private _dir = getDir _pad;

    private _heli = createVehicle [_heliClass, _pos, [], 0, "NONE"];
    if (isNull _heli) exitWith {
        [format ["SPAWN FAILED. %1 INVALID OR MOD NOT LOADED.", _heliClass]] remoteExec ["systemChat", _player];
    };
    _heli setPosATL _pos;
    _heli setDir _dir;
    _heli setVehicleAmmo 1;

    // Clear any existing crew (unmanned spawn)
    { _heli deleteVehicleCrew _x } forEach crew _heli;

    private _displayName = getText (configFile >> "CfgVehicles" >> _heliClass >> "displayName");
    if (_displayName == "") then { _displayName = _heliClass };
    private _padNum = (FADE_helipadList findIf { (_x select 0) == _pad }) + 1;
    private _padDisplay = format ["Pad %1", _padNum];
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
    call FADE_updateHelipadMarkers;
};

// -----------------------------------------------------------------------------
// Despawn any vehicle (server)
// -----------------------------------------------------------------------------
FADE_despawnVehicle = {
    if (!isServer) exitWith {};
    params ["_veh", "_player"];
    _veh = [_veh] call FADE_fnc_vehicleFromRpcParam;
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith { ["VEHICLE MUST BE WITHIN 1000M OF BASE TO DESPAWN."] remoteExec ["systemChat", _player] };
    // Eject all crew (players and AI) before despawning
    private _crew = crew _veh;
    { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
    deleteVehicle _veh;
    ["VEHICLE DESPAWNED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// -----------------------------------------------------------------------------
// Delete wrecks within 2km of the vehicle terminal (server).
// Triggered from Vehicle GUI header button (two-click confirm client-side).
// -----------------------------------------------------------------------------
FADE_deleteWrecksNearVehicleTerminal = {
    params ["_player"];
    if (isNull _player) exitWith {};
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};

    private _terminal = missionNamespace getVariable ["FADE_vehicleTerminal", objNull];
    if (isNull _terminal) then { _terminal = missionNamespace getVariable ["FADE_vehicleBoard", objNull] };
    private _center = if (!isNull _terminal) then { getPosATL _terminal } else { getPosATL _player };
    private _radius = 2000;
    private _removed = 0;

    private _near = nearestObjects [_center, ["AllVehicles", "Wreck_Base"], _radius];
    {
        private _obj = _x;
        if (isNull _obj) then { continue };
        if (_obj isKindOf "Man" || { _obj isKindOf "StaticWeapon" } || { _obj isKindOf "ParachuteBase" }) then { continue };

        private _isWreckObject = _obj isKindOf "Wreck_Base";
        private _isDeadVehicle = (_obj isKindOf "AllVehicles") && { !alive _obj };
        if (!(_isWreckObject || _isDeadVehicle)) then { continue };

        if (_obj isKindOf "AllVehicles") then {
            {
                if (isPlayer _x) then { moveOut _x } else { _obj deleteVehicleCrew _x };
            } forEach crew _obj;
        };
        deleteVehicle _obj;
        _removed = _removed + 1;
    } forEach _near;

    private _origin = if (!isNull _terminal) then { "vehicle terminal" } else { "your position" };
    [format ["WRECK CLEANUP COMPLETE: %1 REMOVED (2KM FROM %2).", _removed, toUpper _origin]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Full repair / refuel / rearm for a vehicle at base (server). Vehicle GUI.
// Distance rule matches despawn.
// -----------------------------------------------------------------------------
FADE_serviceVehicle = {
    params ["_veh", "_player"];
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _veh) exitWith { ["VEHICLE DESTROYED."] remoteExec ["systemChat", _player] };
    if (
        _veh isKindOf "Man"
        || { _veh isKindOf "StaticWeapon" }
        || { _veh isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_veh isKindOf "Air" || _veh isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO SERVICE."] remoteExec ["systemChat", _player];
    };
    _veh setFuel 1;
    _veh setDamage 0;
    _veh setVehicleAmmo 1;
    ["VEHICLE REPAIRED, REFUELLED, AND REARMED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// Vehicle GUI: repair only, refuel only, or rearm only (same distance rules as FADE_serviceVehicle)
FADE_serviceVehiclePart = {
    if (!isServer) exitWith {};
    params ["_veh", "_player", ["_part", ""], ["_ratio", -1], ["_magClass", ""], ["_pylonIdx", -1]];
    _veh = [_veh] call FADE_fnc_vehicleFromRpcParam;
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _veh) exitWith { ["VEHICLE DESTROYED."] remoteExec ["systemChat", _player] };
    if (
        _veh isKindOf "Man"
        || { _veh isKindOf "StaticWeapon" }
        || { _veh isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_veh isKindOf "Air" || _veh isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO SERVICE."] remoteExec ["systemChat", _player];
    };
    if !(_ratio isEqualType 0) then { _ratio = -1 };
    if (_ratio >= 0) then { _ratio = (_ratio max 0) min 1 };
    if (isNil "_pylonIdx" || {!(_pylonIdx isEqualType 0)}) then { _pylonIdx = -1 };
    _pylonIdx = round _pylonIdx;

    switch (toLower _part) do {
        case "repair": {
            if (_ratio >= 0) then {
                _veh setDamage (1 - _ratio);
                [format ["VEHICLE HEALTH SET TO %1%%.", round (_ratio * 100)]] remoteExec ["systemChat", _player];
            } else {
                _veh setDamage 0;
                ["VEHICLE REPAIRED."] remoteExec ["systemChat", _player];
            };
        };
        case "refuel": {
            if (_ratio >= 0) then {
                _veh setFuel _ratio;
                [format ["VEHICLE FUEL SET TO %1%%.", round (_ratio * 100)]] remoteExec ["systemChat", _player];
            } else {
                _veh setFuel 1;
                ["VEHICLE REFUELLED."] remoteExec ["systemChat", _player];
            };
        };
        case "rearm": {
            if (_ratio >= 0 && {_pylonIdx >= 1}) then {
                if (_magClass == "") then {
                    private _pm = getPylonMagazines _veh;
                    private _arrIdx = _pylonIdx - 1;
                    if (_arrIdx >= 0 && {_arrIdx < count _pm}) then { _magClass = _pm select _arrIdx };
                };
                private _cfgMag = configFile >> "CfgMagazines" >> _magClass;
                private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
                if (_max <= 0) then { _max = _veh ammoOnPylon _pylonIdx };
                if (!(_max isEqualType 0)) then { _max = 1 };
                if (_max <= 0) then { _max = 1 };
                private _rounds = round (_max * _ratio);
                _rounds = (_rounds max 0) min _max;
                _veh setAmmoOnPylon [_pylonIdx, _rounds];
                [format ["PYLON %1 AMMO SET (%2 / %3).", _pylonIdx, _rounds, _max]] remoteExec ["systemChat", _player];
            } else {
                if (_ratio >= 0 && {_magClass isEqualType ""} && {_magClass != ""}) then {
                    private _didAny = false;
                    private _mags = magazinesAllTurrets _veh;
                    {
                        private _parsed = [_x] call FAC_fires_parseMagTurretRow;
                        _parsed params ["_mag", "_turretPath", "_cur"];
                        if (_mag == _magClass && {_cur >= 0}) then {
                            private _cfgMag = configFile >> "CfgMagazines" >> _mag;
                            private _max = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
                            if (_max <= 0) then { _max = _cur max 1 };
                            if (_max <= 0) then { _max = 1 };
                            private _rounds = round (_max * _ratio);
                            _rounds = (_rounds max 0) min _max;
                            _veh setMagazineTurretAmmo [_mag, _rounds, _turretPath];
                            _didAny = true;
                        };
                    } forEach _mags;
                    if (_didAny) then {
                        [format ["AMMO LOAD SET FOR %1 (%2%%).", _magClass, round (_ratio * 100)]] remoteExec ["systemChat", _player];
                    } else {
                        ["AMMO TYPE NOT FOUND ON VEHICLE."] remoteExec ["systemChat", _player];
                    };
                } else {
                    _veh setVehicleAmmo 1;
                    ["VEHICLE REARMED."] remoteExec ["systemChat", _player];
                };
            };
        };
        default {
            ["INVALID SERVICE REQUEST."] remoteExec ["systemChat", _player];
        };
    };
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// -----------------------------------------------------------------------------
// Spawn land vehicle at VEH_* using safe-pos search with occupancy checks.
// -----------------------------------------------------------------------------
FADE_spawnLandVehicle = {
    params ["_vehicleClass", "_player", ["_vehPointIndex", -1]];
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith {
        ["INVALID VEHICLE CLASS."] remoteExec ["systemChat", _player];
    };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith {
        [format ["UNKNOWN VEHICLE CLASS: %1", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    if (count FADE_vehiclePoints == 0) exitWith {
        ["NO VEH SPAWN POINTS. CONFIGURE VEH_1/2 IN EDEN."] remoteExec ["systemChat", _player];
    };

    private _candidateIdx = [];
    if (_vehPointIndex >= 0 && {_vehPointIndex < count FADE_vehiclePoints}) then {
        _candidateIdx pushBack _vehPointIndex;
    } else {
        for "_i" from 0 to (count FADE_vehiclePoints - 1) do {
            _candidateIdx pushBack _i;
        };
    };

    private _selectedCenterObj = objNull;
    private _selectedPos = [];
    private _selectedDir = 0;
    private _minDist = 3;
    private _maxDist = 20;
    private _objClear = 3;
    private _vehicleClear = 9;
    private _triesPerPoint = 4;

    {
        private _centerObj = FADE_vehiclePoints select _x;
        private _center = getPosATL _centerObj;
        private _dir = getDir _centerObj;
        private _try = 0;
        while { _try < _triesPerPoint && { _selectedPos isEqualTo [] } } do {
            private _searchMax = _maxDist + (_try * 4);
            private _nearVeh = nearestObjects [_center, ["LandVehicle", "Air"], _searchMax + _vehicleClear];
            private _blacklist = [];
            {
                if (!isNull _x && { alive _x }) then {
                    private _p = getPosATL _x;
                    _blacklist pushBack [_p select 0, _p select 1, _vehicleClear];
                };
            } forEach _nearVeh;

            private _probe = [[_center, _minDist, _searchMax, _objClear, 1, 0.5, 0, _blacklist, _center], _center] call FADE_findSafePosArray;
            if (_probe isEqualType [] && { count _probe >= 2 }) then {
                if (count _probe < 3) then { _probe = [_probe select 0, _probe select 1, 0] };
                private _blocking = nearestObjects [_probe, ["LandVehicle", "Air"], _vehicleClear] select { alive _x };
                if (count _blocking == 0) then {
                    _selectedCenterObj = _centerObj;
                    _selectedPos = _probe;
                    _selectedDir = _dir;
                };
            };
            _try = _try + 1;
        };
        if !(_selectedPos isEqualTo []) exitWith {};
    } forEach _candidateIdx;

    if (_selectedPos isEqualTo []) exitWith {
        ["NO CLEAR VEH SPAWN SLOT. DESPAWN OR MOVE NEARBY VEHICLES."] remoteExec ["systemChat", _player];
    };

    private _veh = createVehicle [_vehicleClass, _selectedPos, [], 0, "NONE"];
    if (isNull _veh) exitWith {
        [format ["SPAWN FAILED: %1.", _vehicleClass]] remoteExec ["systemChat", _player];
    };
    _veh setPosATL _selectedPos;
    _veh setDir _selectedDir;
    _veh setVehicleAmmo 1;
    { _veh deleteVehicleCrew _x } forEach crew _veh;

    private _displayName = getText (configFile >> "CfgVehicles" >> _vehicleClass >> "displayName");
    if (_displayName == "") then { _displayName = _vehicleClass };
    private _vehIdx = FADE_vehiclePoints find _selectedCenterObj;
    private _padDisplay = if (_vehIdx >= 0) then { format ["VEH %1", _vehIdx + 1] } else { "vehicle spawn" };
    [format ["%1 SPAWNED AT %2.", _displayName, _padDisplay]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Duplicate a vehicle at base: fresh spawn (full fuel/damage default) via same rules as Vehicle GUI spawn.
// -----------------------------------------------------------------------------
FADE_duplicateVehicleAtBase = {
    if (!isServer) exitWith {};
    params ["_src", "_player"];
    _src = [_src] call FADE_fnc_vehicleFromRpcParam;
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNull _src) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    if (!alive _src) exitWith { ["CANNOT DUPLICATE A DESTROYED VEHICLE."] remoteExec ["systemChat", _player] };
    if (
        _src isKindOf "Man"
        || { _src isKindOf "StaticWeapon" }
        || { _src isKindOf "ParachuteBase" }
    ) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    if (!(_src isKindOf "Air" || _src isKindOf "LandVehicle")) exitWith {
        ["SELECT AN AIRCRAFT OR LAND VEHICLE."] remoteExec ["systemChat", _player];
    };
    private _dist = (getPosATL _src) distance FADE_basePos;
    if (_dist > 1000) exitWith {
        ["VEHICLE MUST BE WITHIN 1000M OF BASE TO DUPLICATE."] remoteExec ["systemChat", _player];
    };
    private _cls = typeOf _src;
    if (_src isKindOf "Air") then {
        [_cls, _player, -1] call FADE_spawnHeli;
    } else {
        [_cls, _player, -1] call FADE_spawnLandVehicle;
    };
};

// -----------------------------------------------------------------------------
// Return list of all vehicles at base with pad/location info [[vehicle, padDisplayName], ...]
// -----------------------------------------------------------------------------
FADE_requestVehiclesAtBase = {
    params ["_player"];
    if (isNull _player) exitWith {};
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    private _pos = FADE_basePos;
    if (_pos isEqualType objNull) then { _pos = getPosATL _pos };
    private _near = nearestObjects [_pos, ["Air", "LandVehicle"], 1000];
    private _result = [];
    {
        if (!isNull _x && { alive _x }) then {
            private _vPos = getPosATL _x;
            private _padName = "";
            if (_x isKindOf "Air") then {
                { _x params ["_padObj", "_padId"]; if ((getPosATL _padObj) distance _vPos <= 10) exitWith { _padName = format ["Pad %1", (_forEachIndex + 1)] } } forEach FADE_helipadList;
            } else {
                { private _p = getPosATL _x; if (_vPos distance _p <= 15) exitWith { _padName = format ["VEH %1", (_forEachIndex + 1)] } } forEach FADE_vehiclePoints;
            };
            if (_padName == "") then { _padName = "Base" };
            _result pushBack [_x, _padName];
        };
    } forEach _near;
    [_result] remoteExec ["FADE_receiveVehiclesAtBase", _player];
};

// -----------------------------------------------------------------------------
// Enemy vehicles: fill primary gunner if defined and empty (promote cargo, else spawn)
// Params: [_vehicle, optional _unitClassArray]  -  classes default from FADE_enemyUnits / fallback
// -----------------------------------------------------------------------------
FADE_ensureEnemyVehicleGunner = {
    params ["_veh", ["_unitClasses", []]];
    if (!isServer) exitWith {};
    if (isNull _veh || !alive _veh) exitWith {};
    if ((_veh emptyPositions "gunner") <= 0) exitWith {};
    private _have = gunner _veh;
    if (!isNull _have && { alive _have }) exitWith {};

    private _classes = if (_unitClasses isEqualTo []) then {
        private _eu = missionNamespace getVariable ["FADE_enemyUnits", []];
        if (_eu isEqualTo []) then {
            +(missionNamespace getVariable ["FADE_fallbackEnemyUnits", ["O_Soldier_F"]])
        } else { +_eu }
    } else { +_unitClasses };
    if (_classes isEqualTo []) exitWith {};

    private _cargoGuy = objNull;
    {
        if (!alive _x) then {} else {
            if (vehicle _x == _veh) then {
                private _ar = assignedVehicleRole _x;
                if (_ar isEqualType [] && { count _ar > 0 && { (_ar select 0) == "Cargo" } }) then {
                    _cargoGuy = _x;
                };
            };
        };
        if (!isNull _cargoGuy) exitWith {};
    } forEach crew _veh;

    if (!isNull _cargoGuy) then {
        private _crewGrp = if (!isNull driver _veh) then { group driver _veh } else { grpNull };
        if (!isNull _crewGrp && { group _cargoGuy != _crewGrp }) then {
            [_cargoGuy] joinSilent _crewGrp;
        };
        _cargoGuy assignAsGunner _veh;
        _cargoGuy moveInGunner _veh;
    };

    if (!isNull gunner _veh && { alive gunner _veh }) exitWith {};

    private _grp = if (!isNull driver _veh) then { group driver _veh } else { grpNull };
    private _side = if (!isNull _grp) then { side _grp } else { missionNamespace getVariable ["FADE_sideEnemy", east] };
    if (isNull _grp) then { _grp = createGroup _side };
    private _spawnAt = getPosATL _veh;
    private _attempts = 0;
    while { (_veh emptyPositions "gunner" > 0) && { _attempts < 4 } } do {
        _attempts = _attempts + 1;
        private _u = _grp createUnit [selectRandom _classes, _spawnAt, [], 0, "NONE"];
        if (isNull _u) exitWith {};
        _u assignAsGunner _veh;
        _u moveInGunner _veh;
        if (!isNull gunner _veh && { alive gunner _veh }) exitWith {};
    };
};

// -----------------------------------------------------------------------------
// Get cargo (passenger) seat count for a vehicle class
// -----------------------------------------------------------------------------
FADE_getCargoSeats = {
    params ["_vehicleClass"];
    if (_vehicleClass isEqualType objNull) then { _vehicleClass = typeOf _vehicleClass };
    if (isNil "_vehicleClass" || { _vehicleClass == "" }) exitWith { 6 };
    if (!isClass (configFile >> "CfgVehicles" >> _vehicleClass)) exitWith { 6 };
    private _total = [_vehicleClass, true] call BIS_fnc_crewCount;
    private _crew = [_vehicleClass, false] call BIS_fnc_crewCount;
    ((_total - _crew) max 1) min 24
};

// -----------------------------------------------------------------------------
// Time & weather (server) - syncs to all clients in MP
// -----------------------------------------------------------------------------
FADE_setTime = {
    params ["_hour", "_player"];
    _hour = (_hour max 0) min 23;
    private _date = date;
    setDate [_date select 0, _date select 1, _date select 2, _hour, _date select 4];
    [format ["TIME SET %1:00 ZULU.", _hour]] remoteExec ["systemChat", _player];
};

FADE_setWeather = {
    params ["_preset", "_player"];
    if !(_preset in ["Clear", "Overcast", "Foggy", "Rain", "Storm", "FaceMission"]) exitWith {
        ["UNKNOWN WEATHER PRESET."] remoteExec ["systemChat", _player];
    };
    [_preset] call FADE_applyWeatherPreset;
    missionNamespace setVariable ["FADE_scenarioWeatherParams", ([_preset] call FADE_getWeatherParamsForPresetName), true];
    [format ["WEATHER SET: %1.", _preset]] remoteExec ["systemChat", _player];
};

// -----------------------------------------------------------------------------
// Optional player copilot helper (one AI per player, keyed by UID)
// -----------------------------------------------------------------------------
FADE_copilotByUid = createHashMap;

FADE_getCopilotForPlayer = {
    params ["_player"];
    if (isNull _player) exitWith { objNull };
    private _uid = getPlayerUID _player;
    if (_uid == "") exitWith { objNull };
    private _copilot = FADE_copilotByUid getOrDefault [_uid, objNull];
    if (isNull _copilot || { !alive _copilot }) then {
        FADE_copilotByUid deleteAt _uid;
        _copilot = objNull;
    };
    _copilot
};

FADE_requestCopilotState = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _cp = [_player] call FADE_getCopilotForPlayer;
    [!isNull _cp] remoteExec ["FADE_receiveCopilotState", _player];
};

FADE_spawnCopilot = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _existing = [_player] call FADE_getCopilotForPlayer;
    if (!isNull _existing) exitWith {
        ["You already have a copilot."] remoteExec ["systemChat", _player];
        [true] remoteExec ["FADE_receiveCopilotState", _player];
    };

    private _spawnPos = +FADE_basePos;
    if (count _spawnPos < 3) then { _spawnPos = [_spawnPos select 0, _spawnPos select 1, 0] };
    _spawnPos = [[_spawnPos, 8, 20, 2, 1, 0.3, 0, [], _spawnPos], _spawnPos] call FADE_findSafePosArray;
    if (count _spawnPos < 3) then { _spawnPos = [(_spawnPos select 0), (_spawnPos select 1), 0] };

    private _grp = group _player;
    if (isNull _grp) then { _grp = createGroup [side _player, true] };
    private _unitClass = "B_Helipilot_F";
    if (side _player == EAST) then { _unitClass = "O_helipilot_F" };
    if (side _player == RESISTANCE) then { _unitClass = "I_helipilot_F" };
    if (side _player == CIVILIAN) then { _unitClass = "C_man_1" };

    private _cp = _grp createUnit [_unitClass, _spawnPos, [], 0, "NONE"];
    if (isNull _cp) exitWith {
        ["Could not spawn copilot at base."] remoteExec ["systemChat", _player];
        [false] remoteExec ["FADE_receiveCopilotState", _player];
    };

    _cp setPosATL _spawnPos;
    _cp setDir random 360;
    _cp setSkill 0.6;
    private _loadout = getUnitLoadout _player;
    if (_loadout isEqualType [] && { count _loadout > 0 }) then { _cp setUnitLoadout _loadout };
    _cp setVariable ["FADE_isPlayerCopilot", true, true];
    _cp setVariable ["FADE_copilotOwnerUID", getPlayerUID _player, true];

    FADE_copilotByUid set [getPlayerUID _player, _cp];

    [_cp, "This is your copilot. Ready at base and awaiting tasking. Over."] call FADE_aiSideChat;
    ["Copilot spawned at base and added to your group."] remoteExec ["systemChat", _player];
    [true] remoteExec ["FADE_receiveCopilotState", _player];
};

FADE_removeCopilot = {
    params ["_player"];
    if (isNull _player) exitWith {};
    private _cp = [_player] call FADE_getCopilotForPlayer;
    if (isNull _cp) exitWith {
        ["No active copilot to remove."] remoteExec ["systemChat", _player];
        [false] remoteExec ["FADE_receiveCopilotState", _player];
    };
    deleteVehicle _cp;
    FADE_copilotByUid deleteAt (getPlayerUID _player);
    ["Copilot removed."] remoteExec ["systemChat", _player];
    [false] remoteExec ["FADE_receiveCopilotState", _player];
};