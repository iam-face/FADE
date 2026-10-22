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
// Despawn any vehicle (server)
// -----------------------------------------------------------------------------
FADE_despawnVehicle = {
    if (!isServer) exitWith {};
    params ["_veh", "_player"];
    _veh = [_veh] call FADE_fnc_vehicleFromRpcParam;
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (isNull _veh) exitWith { ["INVALID VEHICLE."] remoteExec ["systemChat", _player] };
    private _dist = (getPosATL _veh) distance FADE_basePos;
    private _baseR = missionNamespace getVariable ["FADE_buildRadius", 500];
    if (_dist > _baseR) exitWith {
        [format ["VEHICLE MUST BE WITHIN %1M OF BASE TO DESPAWN.", round _baseR]] remoteExec ["systemChat", _player];
    };
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
    if (!isNil "FAC_build_denyService" && { [_player, "vehicles"] call FAC_build_denyService }) exitWith {};
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
    private _baseR = missionNamespace getVariable ["FADE_buildRadius", 500];
    if (_dist > _baseR) exitWith {
        [format ["VEHICLE MUST BE WITHIN %1M OF BASE TO SERVICE.", round _baseR]] remoteExec ["systemChat", _player];
    };
    _veh setFuel 1;
    _veh setDamage 0;
    _veh setVehicleAmmo 1;
    [_veh] call FADE_pylon_sanitizeVehicle;
    ["VEHICLE REPAIRED, REFUELLED, AND REARMED."] remoteExec ["systemChat", _player];
    if (_veh isKindOf "Air") then { call FADE_updateHelipadMarkers };
};

// Vehicle GUI: repair only, refuel only, or rearm only (same distance rules as FADE_serviceVehicle)
FADE_serviceVehiclePart = {
    if (!isServer) exitWith {};
    params ["_veh", "_player", ["_part", ""], ["_ratio", -1], ["_magClass", ""], ["_pylonIdx", -1]];
    _veh = [_veh] call FADE_fnc_vehicleFromRpcParam;
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    if (!isNil "FAC_build_denyService" && { [_player, "vehicles"] call FAC_build_denyService }) exitWith {};
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
    private _baseR = missionNamespace getVariable ["FADE_buildRadius", 500];
    if (_dist > _baseR) exitWith {
        [format ["VEHICLE MUST BE WITHIN %1M OF BASE TO SERVICE.", round _baseR]] remoteExec ["systemChat", _player];
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
                    [_veh] call FADE_pylon_sanitizeVehicle;
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
// Return list of all vehicles at base with pad/location info [[vehicle, padDisplayName], ...]
// -----------------------------------------------------------------------------
FADE_requestVehiclesAtBase = {
    params ["_player"];
    if (isNull _player) exitWith {};
    if ([_player, "FAC_playerCanUseVehicleGui", "Vehicle GUI access denied by lobby settings."] call FAC_lobbyParams_serverDenyUnless) exitWith {};
    private _pos = FADE_basePos;
    if (_pos isEqualType objNull) then { _pos = getPosATL _pos };
    private _baseR = missionNamespace getVariable ["FADE_buildRadius", 500];
    private _near = nearestObjects [_pos, ["Air", "LandVehicle"], _baseR];
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