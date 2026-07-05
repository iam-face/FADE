// -----------------------------------------------------------------------------
// Weather: numeric params [overcast, rain, fogD, fogDecay, fogBase, windStr, windDir, gusts, waves]
// Preset names map to the same values the legacy switch used. Call only on server.
// -----------------------------------------------------------------------------
FADE_getWeatherParamsForPresetName = {
    params ["_name"];
    switch _name do {
        case "Clear": { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Overcast": { [0.5, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Foggy": { [0.3, 0, 0.5, 0.01, 0, 0, 0, 0, 0] };
        case "Rain": { [0.8, 0.5, 0.1, 0.01, 0, 0, 0, 0, 0] };
        case "Storm": { [1, 1, 0.2, 0.01, 0, 0, 0, 0, 0] };
        case "FaceMission": { [1, 1, 0.5, 0.01, 0, 0, 0, 0, 0] };
        default { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
    };
};

FADE_applyWeatherFromParams = {
    params ["_a"];
    if (!(_a isEqualType []) || { count _a < 9 }) exitWith {};
    _a params ["_oc", "_rn", "_fd", "_fde", "_fb", "_wS", "_wD", "_gs", "_wv"];
    0 setOvercast ((_oc max 0) min 1);
    0 setRain ((_rn max 0) min 1);
    0 setFog [((_fd max 0) min 1), ((_fde max 0) min 1), (_fb max 0) min 500];
    0 setWindStr ((_wS max 0) min 1);
    0 setWindDir (_wD % 360);
    0 setGusts ((_gs max 0) min 1);
    0 setWaves ((_wv max 0) min 1);
    forceWeatherChange;
};

FADE_applyWeatherPreset = {
    params ["_preset"];
    private _p = [_preset] call FADE_getWeatherParamsForPresetName;
    [_p] call FADE_applyWeatherFromParams;
};

// -----------------------------------------------------------------------------
// Pseudo time compression (server): exact real-time scaling with skipTime.
// IMPORTANT: no 'sleep' here (sleep is simulation-time and can cause runaway).
// Target: 100x means 100 mission-seconds per 1 real second.
// We keep engine 1x and add only extra: (scale - 1) * realDelta.
// -----------------------------------------------------------------------------
FADE_timeCompressionPollSec = 1;
[] spawn {
    private _lastTick = diag_tickTime;
    private _nextTick = _lastTick + FADE_timeCompressionPollSec;
    while { true } do {
        waitUntil { diag_tickTime >= _nextTick };
        private _now = diag_tickTime;
        private _realDelta = _now - _lastTick;
        _lastTick = _now;
        _nextTick = _now + FADE_timeCompressionPollSec;
        if (_realDelta <= 0) then { continue };

        private _scale = missionNamespace getVariable ["FADE_timeCompressionScale", 1];
        _scale = (_scale max 1) min 100;
        if (_scale <= 1) then { continue };

        // skipTime expects hours
        private _extraHours = ((_scale - 1) * _realDelta) / 3600;
        if (_extraHours > 0) then { skipTime _extraHours };
    };
};

// Apply initial time and weather from Config (server; syncs to clients)
private _initHour = missionNamespace getVariable ["FADE_scenarioTime", 18];
private _initWeather = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
private _initWp = missionNamespace getVariable ["FADE_scenarioWeatherParams", []];
private _date = date;
setDate [_date select 0, _date select 1, _date select 2, _initHour, _date select 4];
if ((count _initWp) >= 9) then {
    [_initWp] call FADE_applyWeatherFromParams;
} else {
    [_initWeather] call FADE_applyWeatherPreset;
};

// Ambient civilians and Enemy AAA run after FADE_basePos + dynamic civ zones (see below after BASE_1 / helipad resolution).
call compile preprocessFileLineNumbers "rsc\RoadblockCommon.sqf";
// Dynamic corridor roadblocks (FADE_dynamicRoadblocksEnabled + Scenario Enemy Patrols; see Config.sqf)
if (missionNamespace getVariable ["FADE_dynamicRoadblocksEnabled", false]) then {
    [] execVM "rsc\DynamicRoadblocks.sqf";
};
[] execVM "rsc\DummyUnits.sqf";

// Helper: collect Eden objects by variable name
FADE_collectEdenNames = {
    params ["_names"];
    _names apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x }
};

// Pads: array of [object, padName] for spawn logic (planes excluded from FADE_planeForbiddenPads)
FADE_helipadList = [];
{
    private _obj = missionNamespace getVariable [_x, objNull];
    if (!isNull _obj) then { FADE_helipadList pushBack [_obj, _x] };
} forEach (missionNamespace getVariable ["FADE_padNames", ["HP_1","HP_2","HP_3"]]);
FADE_helipads = FADE_helipadList apply { _x select 0 };  // objects only (for base pos, etc.)
FADE_padIndicators = (missionNamespace getVariable ["FADE_padIndicatorNames", []]) apply { missionNamespace getVariable [_x, objNull] };
FADE_padIndicators = FADE_padIndicators select { !isNull _x };
// Interactive boards: vehicle sign (vehBoard: texture only); terminalVeh = Manage Vehicles action (fallback: vehBoard)
FADE_vehicleBoard = missionNamespace getVariable ["vehBoard", objNull];
FADE_vehicleTerminal = missionNamespace getVariable ["terminalVeh", objNull];
FADE_missionBoard = missionNamespace getVariable ["missionBoard", objNull];
FADE_boards = [FADE_vehicleBoard, FADE_missionBoard] select { !isNull _x };

// FIRES range terminal (terminalFires) + game logic slots firesPos_*  -  rsc\FiresArtilleryList.sqf, rsc\FiresGui.sqf
call compile preprocessFileLineNumbers "rsc\FiresArtilleryList.sqf";
FAC_fires_approvedClasses = [];
{ FAC_fires_approvedClasses pushBack (_x select 2) } forEach FAC_fires_artilleryDefinitions;
private _firesNames = missionNamespace getVariable ["FADE_firesPosNames", ["firesPos_1", "firesPos_2", "firesPos_3", "firesPos_4", "firesPos_5", "firesPos_6"]];
FADE_fires_slots = [];
{ FADE_fires_slots pushBack [_x, missionNamespace getVariable [_x, objNull], objNull] } forEach _firesNames;
FADE_firesTerminal = missionNamespace getVariable ["terminalFires", objNull];
FADE_sniperTerminal = missionNamespace getVariable ["terminalSniper", objNull];
missionNamespace setVariable ["FADE_sniperTerminal", FADE_sniperTerminal, true];
FADE_terminalRange = missionNamespace getVariable ["terminalRange", objNull];
missionNamespace setVariable ["FADE_terminalRange", FADE_terminalRange, true];

// Medical training terminal (terminalMedical) + dummies  -  rsc\MedicalTrainingKAT.sqf, rsc\MedicalTrainingGui.sqf (ACE + KAM)
call compile preprocessFileLineNumbers "rsc\MedicalTrainingKAT_fractureLocal.sqf";
call compile preprocessFileLineNumbers "rsc\MedicalTrainingKAT.sqf";
FADE_medicalTrainingTerminal = missionNamespace getVariable ["terminalMedical", objNull];
FADE_medTrain_maxDummies = 8;
FADE_medTrainingDummies = [];

// magazinesAllTurrets row layout: vanilla is [turretPath, magazineClass, ammo]; some mod assets use [magazineClass, turretPath, ammo].
FAC_fires_parseMagTurretRow = {
    params ["_row"];
    if (!(_row isEqualType []) || {count _row < 3}) exitWith { ["", [], -1] };
    private _a0 = _row select 0;
    private _a1 = _row select 1;
    private _a2 = _row select 2;
    if (_a0 isEqualType [] && {_a1 isEqualType ""} && {_a2 isEqualType 0}) exitWith { [_a1, _a0, _a2] };
    if (_a0 isEqualType "" && {_a1 isEqualType []} && {_a2 isEqualType 0}) exitWith { [_a0, _a1, _a2] };
    ["", [], -1]
};

FAC_fires_publishState = {
    if (!isServer) exitWith {};
    {
        private _entry = _x;
        _entry params ["_slotName", "_logicObj", "_veh"];
        if (!isNull _veh && {!alive _veh}) then {
            private _i = FADE_fires_slots findIf { (_x select 0) == _slotName };
            if (_i >= 0) then {
                FADE_fires_slots set [_i, [_slotName, _logicObj, objNull]];
            };
        };
    } forEach FADE_fires_slots;

    private _out = [];
    {
        _x params ["_slotName", "_logicObj", "_veh"];
        private _cls = if (isNull _veh || {!alive _veh}) then { "" } else { typeOf _veh };
        private _ammo = 0;
        private _magState = [];
        if (_cls != "" && {!isNull _veh} && {alive _veh}) then {
            // Per magazine class: total rounds on piece / total capacity (all slots of that type).
            private _agg = [];

            private _addMagRow = {
                params ["_mag", "_cur", "_cap"];
                if (!(_mag isEqualType "") || {_mag == ""} || {!(_cur isEqualType 0)}) exitWith {};
                if (_cap <= 0) then { _cap = 1 };
                private _mi = _agg findIf { (_x select 0) == _mag };
                if (_mi < 0) then {
                    _agg pushBack [_mag, _cur, _cap];
                } else {
                    private _e = _agg select _mi;
                    _e set [1, (_e select 1) + _cur];
                    _e set [2, (_e select 2) + _cap];
                };
            };

            // Primary: magazinesAllTurrets  -  one row per loaded magazine slot (layout may vary by asset).
            {
                private _parsed = [_x] call FAC_fires_parseMagTurretRow;
                _parsed params ["_mag", "_turretUnused", "_cur"];
                if (_mag != "" && {_cur >= 0}) then {
                    private _cfgM = configFile >> "CfgMagazines" >> _mag;
                    private _cap = if (isClass _cfgM) then { getNumber (_cfgM >> "count") } else { 0 };
                    if (_cap <= 0) then { _cap = 1 };
                    [_mag, _cur, _cap] call _addMagRow;
                };
            } forEach (magazinesAllTurrets _veh);

            // Fallback: magazinesAmmoFull  -  one entry per magazine instance.
            if (count _agg == 0) then {
                private _full = magazinesAmmoFull _veh;
                {
                    if (_x isEqualType [] && {count _x > 1}) then {
                        private _mag = _x select 0;
                        private _cur = _x select 1;
                        private _cfgM = configFile >> "CfgMagazines" >> _mag;
                        private _cap = if (isClass _cfgM) then { getNumber (_cfgM >> "count") } else { 0 };
                        if (_cap <= 0) then { _cap = 1 };
                        [_mag, _cur, _cap] call _addMagRow;
                    };
                } forEach _full;
            };

            {
                _ammo = _ammo + (_x select 1);
            } forEach _agg;

            _magState = _agg;
        };
        private _nid = if (!isNull _veh && {alive _veh}) then { netId _veh } else { "" };
        _out pushBack [_slotName, _cls, _ammo, _nid, _magState];
    } forEach FADE_fires_slots;
    missionNamespace setVariable ["FAC_fires_clientState", _out, true];
    // Re-broadcast impact-screen toggles so JIP / desynced clients stay aligned with server.
    private _impEn = missionNamespace getVariable ["FAC_firesFoS_impactEnabled", []];
    if (_impEn isEqualType []) then {
        missionNamespace setVariable ["FAC_firesFoS_impactEnabled", +_impEn, true];
    };
};

FADE_fires_requestState = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};
    [] call FAC_fires_publishState;
};

FADE_fires_spawnPiece = {
    params ["_slotName", "_class", "_player"];
    if (!isServer) exitWith {};
    if (isNil "_class" || { _class == "" }) exitWith { ["FIRES: invalid class."] remoteExec ["systemChat", _player]; };
    if (!(_class in FAC_fires_approvedClasses)) exitWith { ["FIRES: class not on approved list."] remoteExec ["systemChat", _player]; };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {
        [format ["FIRES: %1 not in CfgVehicles (mod missing).", _class]] remoteExec ["systemChat", _player];
    };
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _entry = FADE_fires_slots select _idx;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (isNull _logicObj) exitWith { [format ["FIRES: place game logic %1 in Eden.", _slotName]] remoteExec ["systemChat", _player]; };

    if (!isNull _veh && { alive _veh }) then {
        private _crew = crew _veh;
        { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
        deleteVehicle _veh;
    };
    private _pos = getPosATL _logicObj;
    private _dir = getDir _logicObj;
    private _newVeh = createVehicle [_class, _pos, [], 0, "NONE"];
    if (isNull _newVeh) exitWith { ["FIRES: spawn failed."] remoteExec ["systemChat", _player]; };
    _newVeh setPosATL _pos;
    _newVeh setDir _dir;
    _newVeh setVehicleAmmo 1;
    { _newVeh deleteVehicleCrew _x } forEach crew _newVeh;

    FADE_fires_slots set [_idx, [_sn, _logicObj, _newVeh]];
    [_newVeh, _idx] call FAC_firesFoS_server_registerArtilleryPiece;
    [] call FAC_fires_publishState;
    private _dn = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_dn == "") then { _dn = _class };
    [format ["FIRES: %1 spawned at %2.", _dn, _slotName]] remoteExec ["systemChat", _player];
};

FADE_fires_despawnSlot = {
    params ["_slotName", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _entry = FADE_fires_slots select _idx;
    _entry params ["_sn", "_logicObj", "_veh"];
    if (isNull _veh || {!alive _veh}) exitWith {
        FADE_fires_slots set [_idx, [_sn, _logicObj, objNull]];
        [] call FAC_fires_publishState;
        ["FIRES: slot already empty."] remoteExec ["systemChat", _player];
    };
    private _crew = crew _veh;
    { if (isPlayer _x) then { moveOut _x } else { _veh deleteVehicleCrew _x } } forEach _crew;
    deleteVehicle _veh;
    FADE_fires_slots set [_idx, [_sn, _logicObj, objNull]];
    [] call FAC_fires_publishState;
    ["FIRES: piece removed."] remoteExec ["systemChat", _player];
};

FADE_fires_rearmSlot = {
    params ["_slotName", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _veh = (FADE_fires_slots select _idx) select 2;
    if (isNull _veh || {!alive _veh}) exitWith { ["FIRES: nothing to rearm at this slot."] remoteExec ["systemChat", _player]; };
    _veh setVehicleAmmo 1;
    [] call FAC_fires_publishState;
    ["FIRES: ammunition replenished."] remoteExec ["systemChat", _player];
};

FADE_fires_setAmmoAmount = {
    params ["_slotName", "_magClass", "_targetTotal", "_player"];
    if (!isServer) exitWith {};
    private _idx = FADE_fires_slots findIf { (_x select 0) == _slotName };
    if (_idx < 0) exitWith { ["FIRES: unknown slot."] remoteExec ["systemChat", _player]; };
    private _veh = (FADE_fires_slots select _idx) select 2;
    if (isNull _veh || {!alive _veh}) exitWith { ["FIRES: nothing spawned in selected slot."] remoteExec ["systemChat", _player]; };
    if (_magClass == "") exitWith { ["FIRES: select an ammo type first."] remoteExec ["systemChat", _player]; };

    private _rows = [];
    {
        private _parsed = [_x] call FAC_fires_parseMagTurretRow;
        _parsed params ["_mag", "_turretPath", "_cur"];
        if (_mag == _magClass && {_cur >= 0}) then {
            _rows pushBack [_turretPath, _cur];
        };
    } forEach (magazinesAllTurrets _veh);

    if (count _rows == 0) exitWith {
        [format ["FIRES: %1 not found on selected piece.", _magClass]] remoteExec ["systemChat", _player];
    };

    private _cfgMag = configFile >> "CfgMagazines" >> _magClass;
    private _capDefault = if (isClass _cfgMag) then { getNumber (_cfgMag >> "count") } else { 0 };
    if (_capDefault <= 0) then { _capDefault = 1 };

    private _totalMax = 0;
    {
        private _cap = _capDefault;
        _totalMax = _totalMax + _cap;
    } forEach _rows;

    if (isNil "_targetTotal" || {!(_targetTotal isEqualType 0)}) then { _targetTotal = 0 };
    private _target = round ((_targetTotal max 0) min _totalMax);

    private _remaining = _target;
    {
        _x params ["_turretPath", "_curUnused"];
        private _give = _remaining min _capDefault;
        _veh setMagazineTurretAmmo [_magClass, _give, _turretPath];
        _remaining = _remaining - _give;
    } forEach _rows;

    [] call FAC_fires_publishState;
    [format ["FIRES: %1 total set to %2 / %3 rounds.", _magClass, _target, _totalMax]] remoteExec ["systemChat", _player];
};

FADE_fires_spawnAmmoTruck = {
    params [["_player", objNull]];
    if (!isServer) exitWith {};

    private _spawnLogic = missionNamespace getVariable ["firesTruckSpawnPos", objNull];
    if (isNull _spawnLogic) exitWith {
        ["FIRES: place game logic firesTruckSpawnPos in Eden."] remoteExec ["systemChat", _player];
    };

    private _existing = missionNamespace getVariable ["FADE_firesAmmoTruck", objNull];
    if (!isNull _existing && { alive _existing }) then {
        {
            if (isPlayer _x) then { moveOut _x } else { _existing deleteVehicleCrew _x };
        } forEach crew _existing;
        deleteVehicle _existing;
    };

    private _pos = getPosATL _spawnLogic;
    private _dir = getDir _spawnLogic;
    private _truck = createVehicle ["B_Truck_01_ammo_F", _pos, [], 0, "NONE"];
    if (isNull _truck) exitWith {
        ["FIRES: ammo truck spawn failed."] remoteExec ["systemChat", _player];
    };

    _truck setPosATL _pos;
    _truck setDir _dir;
    _truck setVehicleAmmo 1;
    { _truck deleteVehicleCrew _x } forEach crew _truck;
    missionNamespace setVariable ["FADE_firesAmmoTruck", _truck];

    ["FIRES: ammo truck spawned."] remoteExec ["systemChat", _player];
};

[] call FAC_fires_publishState;

// FIRES timed lane drills (rsc\FiresDrillServer.sqf)
call compile preprocessFileLineNumbers "rsc\FiresDrillServer.sqf";

// FIRES fall of shot: observer UAV RTT + per-slot impact screens (rsc\FiresFallOfShot.sqf)
call compile preprocessFileLineNumbers "rsc\FiresFallOfShot.sqf";
if (isNil "FAC_firesFoS_server_init") then {
    diag_log "[FIRES] FiresFallOfShot.sqf did not define FAC_firesFoS_server_init (script compile/parse failed  -  check RPT for earlier SQF error).";
} else {
    [] call FAC_firesFoS_server_init;
};

// Cutscene test slice: server fan-out start/stop for RTT camera feed.
call compile preprocessFileLineNumbers "rsc\CutsceneServer.sqf";

// CQB Training Shoothouse - single board (cqbBoard) and position triggers (CQB_POS_*)
FADE_cqbBoard = missionNamespace getVariable ["cqbBoard", objNull];
// CQB loudspeaker (Eden object name cqbLoudspeaker) - 3D SFX via remoteExec to clients (FAC_cqbLoudspeaker_clientPlay)
FADE_cqbLoudspeakerBroadcast = {
    params [["_mode", ""], ["_emitter", objNull]];
    if (!isServer) exitWith {};
    if (_mode == "") exitWith {};
    if (!isNull _emitter) then {
        [_mode, _emitter] remoteExec ["FAC_cqbLoudspeaker_clientPlay", 0];
    } else {
        [_mode] remoteExec ["FAC_cqbLoudspeaker_clientPlay", 0];
    };
};

FADE_cqbPositions = (missionNamespace getVariable ["FADE_cqbPosNames", call {
    private _a = [];
    private _i = 1;
    while { _i <= 49 } do {
        _a pushBack format ["CQB_POS_%1", _i];
        _i = _i + 1;
    };
    _a
}]) apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x };
missionNamespace setVariable ["FADE_cqbPosCount", count FADE_cqbPositions, true];
FADE_cqbDrillActive = false;
FADE_cqbSpawned = [];  // objects and groups to delete on end drill
FADE_cqbEnemyGroups = [];
FADE_cqbWatcherHandle = scriptNull;
FADE_cqbTargetWatcherHandle = scriptNull;
FADE_cqbStarterKilledEh = [];  // [unit, eventHandlerId] while drill active
FADE_cqbStarterUnit = objNull;
FADE_cqbStarterUid = "";
missionNamespace setVariable ["FADE_cqbDrillStartTick", -1];
missionNamespace setVariable ["FADE_cqbLastResult", "", true];

// Apply board textures (Eden names). Non-interactable: base, loadout, music, firing range, teleport.
private _applyBoardTexture = {
    params ["_obj", "_path"];
    if (!isNull _obj && { count (getObjectTextures _obj) > 0 }) then { _obj setObjectTextureGlobal [0, _path] };
};
// Land_MapBoard_01_Wall_F: getObjectTextures is often [] until a texture is set, so the guard above never runs.
private _applyBoardTextureMapWall = {
    params ["_obj", "_path"];
    if (isNull _obj) exitWith {};
    _obj setObjectTextureGlobal [0, _path];
};
// Resolve Eden object name: missionNamespace first, then scan map boards (covers edge cases where name is not in namespace yet).
private _fnc_resolveLandMapBoardWall = {
    params ["_edenName"];
    private _o = missionNamespace getVariable [_edenName, objNull];
    if (!isNull _o) exitWith { _o };
    private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
    private _i = _scan findIf { vehicleVarName _x == _edenName };
    if (_i >= 0) then { _o = _scan select _i };
    _o
};
private _applyBoardTextureMapWallByEdenName = {
    params ["_edenName", "_path"];
    private _o = [_edenName] call _fnc_resolveLandMapBoardWall;
    if (isNull _o) exitWith {};
    _o setObjectTextureGlobal [0, _path];
};
// Vehicle and Missions/Config boards (interactive)
[missionNamespace getVariable ["vehBoard", objNull], "img\vehicles2.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["missionBoard", objNull], "img\laptopScenario.jpg"] call _applyBoardTexture;
// CQB (interactive)
[missionNamespace getVariable ["cqbBoard", objNull], "img\laptopCQB.jpg"] call _applyBoardTexture;
// Base billboards (non-interactable). Add img\base.jpg and uncomment to set texture.
[missionNamespace getVariable ["baseBoard_1", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_2", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["baseBoard_3", objNull], "img\baseBoards.jpg"] call _applyBoardTexture;
// HQ / canvases / admin / banner (non-interactable; Eden object names)
[missionNamespace getVariable ["hqMainBoard", objNull], "img\hqMainBoard2.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_1", objNull], "img\flagCTB.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_2", objNull], "img\flagAustralia.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_3", objNull], "img\loadingb.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["canvas_4", objNull], "img\missionsconfig.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["whiteboardAdmin", objNull], "img\whiteboardAdmin.jpg"] call _applyBoardTextureMapWall;
[missionNamespace getVariable ["bannerSDE", objNull], "img\bannerSDE.jpg"] call _applyBoardTexture;
// Loadout boards above loadout boxes (non-interactable). Names: loadoutboard_1/3/4 in mission.sqm (case-sensitive).
private _loadoutMapTex = "img\whiteboardLoadouts.jpg";
{ [_x, _loadoutMapTex] call _applyBoardTextureMapWallByEdenName } forEach ["loadoutboard_1", "loadoutboard_3", "loadoutboard_4"];
[missionNamespace getVariable ["loadoutBoard_2", objNull], "img\loadouts.jpg"] call _applyBoardTexture;
// Re-apply after init: Eden/custom attributes can run after initServer; inline resolver (spawn cannot see outer private fnc).
[] spawn {
    private _names = ["loadoutboard_1", "loadoutboard_3", "loadoutboard_4"];
    private _p = "img\whiteboardLoadouts.jpg";
    private _apply = {
        params ["_names", "_path"];
        {
            private _en = _x;
            private _o = missionNamespace getVariable [_en, objNull];
            if (isNull _o) then {
                private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
                private _i = _scan findIf { vehicleVarName _x == _en };
                if (_i >= 0) then { _o = _scan select _i };
            };
            if (!isNull _o) then { _o setObjectTextureGlobal [0, _path]; };
        } forEach _names;
    };
    sleep 0.5;
    [_names, _p] call _apply;
    sleep 2;
    [_names, _p] call _apply;
};
// Music board next to jukebox (non-interactable)
[missionNamespace getVariable ["musicBoard", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
// Jukebox radio props (non-interactable texture; actions on Radio_* in initPlayerLocal)
[missionNamespace getVariable ["Radio_1", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_2", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_3", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_4", objNull], "img\laptopJukebox.jpg"] call _applyBoardTexture;
// Firing range sign (non-interactable)
[missionNamespace getVariable ["firingRangeBoard", objNull], "img\signLiveFire.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["signFire_1", objNull], "img\signLiveFire.jpg"] call _applyBoardTexture;
// Teleport boards (Fast Travel GUI) - same signage texture on all boards
{
    [missionNamespace getVariable [_x, objNull], "img\teleporter.jpg"] call _applyBoardTexture;
} forEach [
    "teleportBoard_1", "teleportBoard_2", "teleportBoard_3", "teleportBoard_4",
    "teleportBoard_5", "teleportBoard_6", "teleportBoard_9", "teleportBoard_10"
];
// All loadout boxes (from Config FADE_loadoutBoxNames); each gets loadout actions + ACE init
FADE_loadoutBoxes = (missionNamespace getVariable ["FADE_loadoutBoxNames", ["LOADOUTBOX", "LOADOUTBOX_2"]]) apply { missionNamespace getVariable [_x, objNull] } select { !isNull _x };
FADE_loadoutBox = FADE_loadoutBoxes param [0, objNull];
FADE_loadoutBox2 = FADE_loadoutBoxes param [1, objNull];
FADE_workbench = missionNamespace getVariable [missionNamespace getVariable ["FADE_workbenchEdenName", "objWorkbench"], objNull];
FADE_bSpPoints = [["B_SP_1","B_SP_2","B_SP_3"]] call FADE_collectEdenNames;
FADE_hqRecruitBoard = missionNamespace getVariable ["hqRecruitBoard", objNull];

// ACE Arsenal: init each loadout box if ACE is loaded; FIRES terminal as virtual box for range kit
FADE_isWorkbenchObject = {
    params [["_obj", objNull, [objNull]]];
    !isNull _obj && { !isNull FADE_workbench } && { _obj isEqualTo FADE_workbench }
};

// objWorkbench: full ACE catalog init, then strip everything except weapon attachments (optics, pointers, muzzles, bipods).
FADE_initWorkbenchArsenal = {
    params ["_box"];
    [_box, true, true] call ace_arsenal_fnc_initBox;
    [{
        params ["_box"];
        private _cargo = _box getVariable "ace_arsenal_virtualItems";
        if (isNil "_cargo") exitWith {};
        private _attachments = _cargo get 1;
        private _keep = createHashMap;
        { { _keep set [_x, true]; } forEach (keys (_attachments get _x)); } forEach [0, 1, 2, 3];
        private _all = +([_box] call ace_arsenal_fnc_getVirtualItems);
        private _remove = (keys _all) select { isNil { _keep get _x } };
        if (_remove isNotEqualTo []) then { [_box, _remove, true] call ace_arsenal_fnc_removeVirtualItems; };
    }, [_box]] call CBA_fnc_execNextFrame;
};

if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
    {
        if (!isNull _x) then {
            if ([_x] call FADE_isWorkbenchObject) then { [_x] call FADE_initWorkbenchArsenal } else { [_x, true, true] call ace_arsenal_fnc_initBox };
        };
    } forEach FADE_loadoutBoxes;
    private _ft = missionNamespace getVariable ["FADE_firesTerminal", objNull];
    if (!isNull _ft) then { [_ft, true, true] call ace_arsenal_fnc_initBox };
};

// FADE_heliClasses and FADE_landVehicleClasses already built in single-pass scan above

// Vehicle spawn points (VEH_1, VEH_2) for land vehicles
FADE_vehiclePoints = [["VEH_1", "VEH_2"]] call FADE_collectEdenNames;

// Store original helipad marker text (for restore when pad emptied)
FADE_padMarkerOriginalText = [];
{
    private _mrkName = (missionNamespace getVariable ["FADE_helipadMarkers", []]) param [_forEachIndex, ""];
    if (_mrkName != "" && { getMarkerColor _mrkName != "" }) then {
        private _txt = markerText _mrkName;
        FADE_padMarkerOriginalText set [_forEachIndex, if (_txt != "") then { _txt } else { format ["Pad %1", _forEachIndex + 1] }];
    };
} forEach FADE_helipadList;

// Base position - from BASE_1 (centre of map), fallback to helipad or B_SP
private _baseObj = missionNamespace getVariable ["BASE_1", objNull];
if (!isNull _baseObj) then {
    FADE_basePos = getPosATL _baseObj;
} else {
    if (count FADE_helipads > 0) then {
        FADE_basePos = getPosATL (FADE_helipads select 0);
    } else {
        if (count FADE_bSpPoints > 0) then {
            FADE_basePos = position (FADE_bSpPoints select 0);
        } else {
            FADE_basePos = [5000, 5000, 0];
        };
    };
};

// Civ zone anchors from map named locations (CIV_T_1..n in missionNamespace; replaces Eden CIV_T_* triggers)
call compile preprocessFileLineNumbers "rsc\FADE_civZonesFromLocations.sqf";
call FADE_civZonesFromLocations_build;

// Ambient civilians (scans CIV_T_* refs into FADE_civTriggerNames; road traffic uses active zones  -  ROAD_SP_* only for Intercept Convoy)
0 spawn { execVM "rsc\AmbientCivilians.sqf"; };

// Enemy AAA (dynamic around airborne player aircraft; Off/AAA/AAA+MANPADS)
call compile preprocessFileLineNumbers "rsc\EnemyAAA.sqf";
0 spawn { waitUntil { !isNil "FADE_aaa_applyLevel" }; call FADE_aaa_applyLevel; };

// Map bounds for mission spawns (min/max X and Y); playable area 0..30000 on current terrain
FADE_mapMin = 0;
FADE_mapMax = 30000;
FADE_minDistFromBase = 700;
// Troop Insert LZ and Troop Extract pickup: minimum distance from FADE_basePos (meters)
FADE_troopInsertExtractMinDistFromBase = 2000;
FADE_troopInsertPickupMinDist = 500;           // fresh squad link-up: min offset from transport
FADE_troopInsertPickupMaxDist = 1000;          // fresh squad link-up: max offset from transport
FADE_troopInsertLzMinDistFromPickup = 2500;    // insert LZ must be at least this far from link-up
FADE_troopHeliSiteMaxDistFromCivZone = 250;    // insert/extract LZ/pickup must be within this of a civ zone centre
FADE_troopInsertWaveTimeout = 620;             // max seconds to wait for slowest transport in a wave
// Heli LZ search (FADE_findSafeLZ): loose rules — marker hints area; pilots pick the actual landing spot
FADE_lzClearanceM = 5;                         // min clearance from buildings/walls (trees/bushes allowed closer)
FADE_lzMaxGrad = 0.5;                        // max terrain slope (BIS findSafePos; higher = steeper OK)
FADE_lzSearchRadiusDefault = 80;              // default search disc when caller omits radius
FADE_lzLocalSearchM = 25;                    // findSafePos radius around each random attempt point
FADE_lzMaxAttempts = 30;                      // placement attempts before giving up
FADE_lzBlockObjectTypes = ["Building", "House", "Wall"]; // hard-block only structures, not vegetation

// -----------------------------------------------------------------------------
// Reusable: delete marker only if it exists (avoids "marker not found" in RPT).
// Markers are global; must be deleted on the same machine that created them (server).
// -----------------------------------------------------------------------------
FADE_deleteMarkerSafe = {
    params ["_markerName"];
    if (_markerName != "" && { getMarkerColor _markerName != "" }) then { deleteMarker _markerName };
};

// Enemy retreat: when 50% of mission enemies are dead, each remaining unit gets a skill-based chance to retreat (move 2 km away from base). Skill 0 = 100% retreat, skill 1 = 0%, linear in between. Call FADE_registerEnemyRetreat once per mission with enemy groups. Runs on server only (initServer / Missions.sqf).
FADE_retreatCheckInterval = 10;  // seconds between 50% checks
FADE_retreatDebug = false;  // set true for systemChat messages (retreat trigger, per-unit decisions)
FADE_doEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _skill = missionNamespace getVariable ["FADE_enemySkill", 0.0];
    private _retreatChance = 1 - (_skill max 0 min 1);
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: 50%% threshold reached. Rolling retreat (chance %1%2).", round (_retreatChance * 100), "%"]] remoteExec ["systemChat", 0];
    };
    {
        private _grp = _x;
        if (!isNull _grp && { side _grp == (missionNamespace getVariable ["FADE_sideEnemy", east]) }) then {
            private _toRetreat = [];
            private _staying = [];
            {
                if (alive _x) then {
                    private _roll = random 1;
                    private _retreat = _roll < _retreatChance;
                    if (_debug) then {
                        [format ["Retreat: unit %1 -> %2 (roll %3 vs %4)", _x, if (_retreat) then { "RETREAT" } else { "STAY" }, round (_roll * 100) / 100, round (_retreatChance * 100) / 100]] remoteExec ["systemChat", 0];
                    };
                    if (_retreat) then { _toRetreat pushBack _x } else { _staying pushBack _x };
                };
            } forEach units _grp;
            if (count _toRetreat > 0) then {
                if (_debug) then {
                    [format ["Retreat: group %1 -> %2 retreating, %3 staying. Clearing waypoints.", _grp, count _toRetreat, count _staying]] remoteExec ["systemChat", 0];
                };
                // Clear all current waypoints so retreat replaces orders, not appends
                private _wps = waypoints _grp;
                for "_i" from (count _wps - 1) to 0 step -1 do {
                    deleteWaypoint [_grp, _i];
                };
                _grp setSpeedMode "FULL";
                {
                    private _unitPos = getPos _x;
                    if (count _unitPos >= 2) then {
                        private _dirToBase = _x getDir _basePos;
                        private _dest = _unitPos getPos [2000, _dirToBase + 180];
                        _x doMove _dest;
                        _x setUnitPos "AUTO";
                    };
                } forEach _toRetreat;
            };
        };
    } forEach _groups;
    if (_debug) then {
        [format ["Retreat: done. Orders sent (doMove 2km away from base)."]] remoteExec ["systemChat", 0];
    };
};
FADE_registerEnemyRetreat = {
    params ["_groups", "_basePos"];
    if (!(_groups isEqualType [])) exitWith {}; // avoid foreach Type Bool (bad caller / scope collision)
    if (_groups isEqualTo [] || { _basePos isEqualTo [] }) exitWith {};
    private _initialTotal = 0;
    { _initialTotal = _initialTotal + count units _x } forEach _groups;
    if (_initialTotal <= 1) exitWith {};  // 50% of 0 or 1 is pointless; avoid spawning check thread
    private _interval = missionNamespace getVariable ["FADE_retreatCheckInterval", 10];
    private _debug = missionNamespace getVariable ["FADE_retreatDebug", false];
    if (_debug) then {
        [format ["Retreat: registered %1 groups, %2 total enemies. Checking every %3s.", count _groups, _initialTotal, _interval]] remoteExec ["systemChat", 0];
    };
    [_groups, _basePos, _initialTotal, _interval, _debug] spawn {
        params ["_groups", "_basePos", "_initialTotal", "_interval", "_debug"];
        waitUntil {
            sleep _interval;
            private _alive = 0;
            { _alive = _alive + ({ alive _x } count units _x) } forEach _groups;
            _alive <= _initialTotal * 0.5
        };
        private _aliveNow = 0;
        { _aliveNow = _aliveNow + ({ alive _x } count units _x) } forEach _groups;
        if (_debug) then {
            [format ["Retreat: 50%% condition met (%1 alive / %2 initial). Applying retreat roll.", _aliveNow, _initialTotal]] remoteExec ["systemChat", 0];
        };
        [_groups, _basePos] call FADE_doEnemyRetreat;
    };
};

// -----------------------------------------------------------------------------
// Mission entity registry  -  track groups / vehicles / objects per task for abort + finish cleanup
// (QRF trucks, virtual-garrison spawns, convoy vehicles, mission composition, etc.)
// -----------------------------------------------------------------------------
FADE_missionEnt_init = {
    params ["_taskId"];
    if (_taskId == "") exitWith {};
    missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], createHashMapFromArray [
        ["groups", []],
        ["groupRefs", []],
        ["vehicles", []],
        ["objects", []],
        ["markers", []]
    ]];
    missionNamespace setVariable [format ["FADE_missionEnt_cleaned_%1", _taskId], false];
};

FADE_missionEnt_get = {
    params ["_taskId"];
    if (_taskId == "") exitWith { createHashMap };
    private _ent = missionNamespace getVariable [format ["FADE_missionEnt_%1", _taskId], createHashMap];
    if (_ent isEqualType createHashMap) then { _ent } else { createHashMap }
};

FADE_missionEnt_bindGroups = {
    params ["_taskId", "_groupsArr"];
    if (_taskId == "" || { !(_groupsArr isEqualType []) }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _refs = +(_ent getOrDefault ["groupRefs", []]);
    if (!(_groupsArr in _refs)) then {
        _refs pushBack _groupsArr;
        _ent set ["groupRefs", _refs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerGroup = {
    params ["_taskId", "_grp"];
    if (_taskId == "" || { isNull _grp }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _grps = +(_ent getOrDefault ["groups", []]);
    if (!(_grp in _grps)) then {
        _grps pushBack _grp;
        _ent set ["groups", _grps];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerVehicle = {
    params ["_taskId", "_veh"];
    if (_taskId == "" || { isNull _veh }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _vehs = +(_ent getOrDefault ["vehicles", []]);
    if (!(_veh in _vehs)) then {
        _vehs pushBack _veh;
        _ent set ["vehicles", _vehs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerObject = {
    params ["_taskId", "_obj"];
    if (_taskId == "" || { isNull _obj }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _objs = +(_ent getOrDefault ["objects", []]);
    if (!(_obj in _objs)) then {
        _objs pushBack _obj;
        _ent set ["objects", _objs];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

FADE_missionEnt_registerMarker = {
    params ["_taskId", "_markerName"];
    if (_taskId == "" || { _markerName isEqualTo "" }) exitWith {};
    private _ent = [_taskId] call FADE_missionEnt_get;
    if (count keys _ent == 0) then { [_taskId] call FADE_missionEnt_init; _ent = [_taskId] call FADE_missionEnt_get };
    private _marks = +(_ent getOrDefault ["markers", []]);
    if (!(_markerName in _marks)) then {
        _marks pushBack _markerName;
        _ent set ["markers", _marks];
        missionNamespace setVariable [format ["FADE_missionEnt_%1", _taskId], _ent];
    };
};

// Delete all map markers for a mission task (registry, legacy vars, player vars, FADE_* sweep). Idempotent.
FADE_cleanupMissionMarkers = {
    params ["_taskId", ["_player", objNull]];
    if (_taskId == "") exitWith {};

    private _ent = missionNamespace getVariable [format ["FADE_missionEnt_%1", _taskId], createHashMap];
    if (_ent isEqualType createHashMap) then {
        { [_x] call FADE_deleteMarkerSafe } forEach (_ent getOrDefault ["markers", []]);
    };

    private _sdM = missionNamespace getVariable ["FADE_searchDestroyMarker_" + _taskId, ""];
    if (_sdM != "") then { [_sdM] call FADE_deleteMarkerSafe };
    missionNamespace setVariable ["FADE_searchDestroyMarker_" + _taskId, nil];
    private _sdZ = missionNamespace getVariable ["FADE_searchDestroyZoneMarker_" + _taskId, ""];
    if (_sdZ != "") then { [_sdZ] call FADE_deleteMarkerSafe };
    missionNamespace setVariable ["FADE_searchDestroyZoneMarker_" + _taskId, nil];

    private _aoM = missionNamespace getVariable ["FADE_aoMarkers_" + _taskId, []];
    if (_aoM isEqualType []) then {
        { [_x] call FADE_deleteMarkerSafe } forEach _aoM;
    };
    missionNamespace setVariable ["FADE_aoMarkers_" + _taskId, nil];

    {
        if ((_x getVariable ["FADE_myMissionTaskId", ""]) == _taskId) then {
            [_x getVariable ["FADE_myMissionMarker", ""]] call FADE_deleteMarkerSafe;
            [_x getVariable ["FADE_myMissionMarkerEnd", ""]] call FADE_deleteMarkerSafe;
            _x setVariable ["FADE_myMissionMarker", nil, true];
            _x setVariable ["FADE_myMissionMarkerEnd", nil, true];
        };
    } forEach allPlayers;

    if (!isNull _player) then {
        [_player getVariable ["FADE_myMissionMarker", ""]] call FADE_deleteMarkerSafe;
        [_player getVariable ["FADE_myMissionMarkerEnd", ""]] call FADE_deleteMarkerSafe;
        _player setVariable ["FADE_myMissionMarker", nil, true];
        _player setVariable ["FADE_myMissionMarkerEnd", nil, true];
    };

    {
        if ((_x find "FADE_") == 0 && { _x find _taskId >= 0 }) then {
            [_x] call FADE_deleteMarkerSafe;
        };
    } forEach allMapMarkers;
};

FADE_missionEnt_deleteGroupFull = {
    params ["_grp"];
    if (isNull _grp) exitWith {};
    private _vehs = [];
    {
        if (!isNull _x) then {
            private _v = vehicle _x;
            if (!isNull _v && { _v != _x } && { !(_v in _vehs) }) then { _vehs pushBack _v };
            deleteVehicle _x;
        };
    } forEach +units _grp;
    {
        if (!isNull _x) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach crew _x;
            if (alive _x) then { deleteVehicle _x };
        };
    } forEach _vehs;
    if (!isNull _grp) then { deleteGroup _grp };
};

FADE_missionEnt_deleteVehicleFull = {
    params ["_veh"];
    if (isNull _veh) exitWith {};
    private _cg = _veh getVariable ["FADE_eeQrfCargoGrp", grpNull];
    if (isNull _cg) then { _cg = _veh getVariable ["FADE_opforAirCargoGrp", grpNull] };
    if (!isNull _cg) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _cg;
        deleteGroup _cg;
    };
    { if (!isNull _x) then { deleteVehicle _x } } forEach crew _veh;
    private _dg = group driver _veh;
    if (!isNull _dg) then {
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _dg;
        if (count units _dg == 0) then { deleteGroup _dg };
    };
    if (!isNull _veh) then { deleteVehicle _veh };
};

// -----------------------------------------------------------------------------
// Counter-attack helpers - cargo capacity (cached per classname), RHS/vanilla fallbacks
// -----------------------------------------------------------------------------
// Returns emptyPositions "cargo" for a classname; caches in missionNamespace (spawn test once per class).
FADE_counterAttack_cargoSeatsForClass = {
    params ["_class"];
    private _key = "FADE_counterAttack_cargo_" + _class;
    private _cached = missionNamespace getVariable [_key, -1];
    if (_cached >= 0) exitWith { _cached };
    if (!(isClass (configFile >> "CfgVehicles" >> _class))) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _testPos = [[FADE_basePos, 1500, 5000, 15, 1, 0.4, 0, [], FADE_basePos], FADE_basePos] call FADE_findSafePosArray;
    if (count _testPos < 2) then { _testPos = [FADE_basePos select 0, FADE_basePos select 1, 0] };
    private _v = createVehicle [_class, _testPos, [], 0, "NONE"];
    if (isNull _v) exitWith {
        missionNamespace setVariable [_key, 0];
        0
    };
    private _n = _v emptyPositions "cargo";
    deleteVehicle _v;
    missionNamespace setVariable [_key, _n];
    _n
};

// Filter classnames to those with at least _minCargo cargo seats (uses cache above).
FADE_counterAttack_filterClassesByMinCargo = {
    params ["_classes", "_minCargo"];
    private _out = [];
    {
        if (([_x] call FADE_counterAttack_cargoSeatsForClass) >= _minCargo) then {
            _out pushBack _x;
        };
    } forEach _classes;
    _out
};

// -----------------------------------------------------------------------------
// QRF hint: red flare high in the air near _center (optionally biased toward friendly players in radius). Server only.
// Params: [_centerATL, _radiusM, _heightM (optional)]
// Uses setPosASL — F_40mm_Red ignores createVehicle ATL and otherwise lands at ground level (feet).
// -----------------------------------------------------------------------------
FADE_qrfSpawnHintFlare = {
    params [["_center", [0, 0, 0]], ["_radiusM", 500], ["_heightM", 100]];
    if (!isServer) exitWith {};
    if (count _center < 2) exitWith {};
    private _centerN = [_center] call FADE_normPos3;
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (isPlayer _x && { alive _x } && { side _x == _sf } && { (_x distance2D _centerN) <= _radiusM }) then {
            private _p = getPosASL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    private _gx = _centerN select 0;
    private _gy = _centerN select 1;
    private _groundRefAsl = getTerrainHeightASL [_gx, _gy];
    if (_n > 0) then {
        private _avg = _acc vectorMultiply (1 / _n);
        _gx = _avg select 0;
        _gy = _avg select 1;
        _groundRefAsl = (_groundRefAsl max (_avg select 2));
    };
    private _flareAsl = [_gx, _gy, _groundRefAsl + (_heightM max 80) + random 25];
    private _flare = createVehicle ["F_40mm_Red", [0, 0, 0], [], 0, "NONE"];
    if (isNull _flare) exitWith {};
    _flare setPosASL _flareAsl;
    _flare setVelocity [0, 0, 0];
    [_flare, 50] spawn {
        params ["_f", "_ttl"];
        sleep _ttl;
        if (!isNull _f) then { deleteVehicle _f };
    };
};
missionNamespace setVariable ["FADE_qrfSpawnHintFlare", FADE_qrfSpawnHintFlare];

// Server: ATL centroid of alive friendly-side players; else any alive player; else _fallback (2â€“3 elements).
FADE_qrfFriendlyCentroidATL = {
    params [["_fallback", [0, 0, 0]]];
    if (count _fallback < 2) exitWith { [0, 0, 0] };
    private _sf = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _acc = [0, 0, 0];
    private _n = 0;
    {
        if (isPlayer _x && { alive _x } && { side _x == _sf }) then {
            private _p = getPosATL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    if (_n > 0) exitWith {
        private _avg = _acc vectorMultiply (1 / _n);
        [(_avg select 0), (_avg select 1), (_avg select 2) max 0]
    };
    _acc = [0, 0, 0];
    _n = 0;
    {
        if (isPlayer _x && { alive _x }) then {
            private _p = getPosATL _x;
            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
            _acc = _acc vectorAdd _p;
            _n = _n + 1;
        };
    } forEach allPlayers;
    if (_n > 0) exitWith {
        private _avg = _acc vectorMultiply (1 / _n);
        [(_avg select 0), (_avg select 1), (_avg select 2) max 0]
    };
    if (count _fallback < 3) then { [(_fallback select 0), (_fallback select 1), 0] } else { +_fallback }
};
missionNamespace setVariable ["FADE_qrfFriendlyCentroidATL", FADE_qrfFriendlyCentroidATL];

// -----------------------------------------------------------------------------
// Counter-attack / QRF (HVT, Hostage, Clear Area, Search & Destroy, Troop Extract, CASEVAC, CSAR, Asset Retrieval, CAS) - reusable server spawn loop.
// Stages truck-mounted infantry from the second-nearest civ zone (by distance
// to the objective); falls back to offset from nearest zone if only one trigger exists.
// Params: [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _skipDetectionWait]
//   _allGroups - reference array; new enemy groups are pushBack'd for mission cleanup.
//   _detectionRadius - optional; <= 0 uses missionNamespace FADE_counterAttackDetectionRadius (default 450).
//   _skipDetectionWait - optional; if true, skip polling for player-in-zone and start first-wave delay immediately (CAS: when friendlies mark).
// Timing defaults (optional missionNamespace): FADE_counterAttackFirstDelayMin/Max (120â€“360s),
//   FADE_counterAttackBetweenMin/Max (540â€“660s), FADE_counterAttackTruckCount (3).
// Vehicle filter: FADE_counterAttackMinCargoSeats (default 4). Fallback trucks if faction has none:
//   FADE_counterAttackRhsFallbacks (RHS GAZ/ZIL/Kamaz/Ural-style), then FADE_counterAttackVanillaFallbacks.
// Poll interval: FADE_counterAttackPollInterval (default 10s) for zone/task checks (not per-frame).
// Wave cap: 1â€“3 waves per mission instance (chosen at random when the counter-attack thread starts).
// If no player remains inside the objective detection radius when a wave spawns, trucks hunt a friendly
// player centroid; driver MOVE+SAD waypoints refresh every FADE_qrfHuntWaypointIntervalS (default 60).
// Not registered with FADE_registerEnemyRetreat (QRF keeps pressure); cleaned with mission groups.
// -----------------------------------------------------------------------------
FADE_counterAttackStart = {
    params [
        "_taskId",
        "_objectivePos",
        "_basePos",
        "_enemyUnits",
        "_allGroups",
        ["_detectionRadius", -1],
        ["_skipDetectionWait", false],
        ["_firstDelayMin", -1],
        ["_firstDelayMax", -1],
        ["_ambientSingleWave", false]
    ];
    if (!isServer) exitWith {};
    if (count _objectivePos < 2 || { count _enemyUnits == 0 }) exitWith {};
    if (_detectionRadius <= 0) then {
        _detectionRadius = missionNamespace getVariable ["FADE_counterAttackDetectionRadius", 450];
    };
    private _firstMin = if (_firstDelayMin >= 0) then { _firstDelayMin } else { missionNamespace getVariable ["FADE_counterAttackFirstDelayMin", 120] };
    private _firstMax = if (_firstDelayMax >= 0) then { _firstDelayMax } else { missionNamespace getVariable ["FADE_counterAttackFirstDelayMax", 360] };
    if (_firstMax < _firstMin) then { _firstMax = _firstMin };
    private _betMin = missionNamespace getVariable ["FADE_counterAttackBetweenMin", 540];
    private _betMax = missionNamespace getVariable ["FADE_counterAttackBetweenMax", 660];
    private _numTrucks = (missionNamespace getVariable ["FADE_counterAttackTruckCount", 3]) max 1;
    private _pollInterval = (missionNamespace getVariable ["FADE_counterAttackPollInterval", 10]) max 1;
    private _applyGrp = missionNamespace getVariable ["FAC_applyEnemyScenarioToGroup", {}];
    if (_applyGrp isEqualTo {}) exitWith {};

    [_taskId, _objectivePos, _basePos, _enemyUnits, _allGroups, _detectionRadius, _firstMin, _firstMax, _betMin, _betMax, _numTrucks, _applyGrp, _pollInterval, _skipDetectionWait, _ambientSingleWave] spawn {
        params [
            "_taskId", "_objectivePos", "_basePos", "_enemyUnits", "_allGroups", "_detectionRadius",
            "_firstMin", "_firstMax", "_betMin", "_betMax", "_numTrucks", "_applyGrp", "_pollInterval", "_skipDetectionWait", "_ambientSingleWave"
        ];
        private _taskDone = if (_ambientSingleWave) then {
            { false }
        } else {
            { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] }
        };
        private _playersInZone = {
            private _ok = false;
            {
                if (isPlayer _x && { alive _x } && { (_x distance2D _objectivePos) < _detectionRadius }) exitWith { _ok = true };
            } forEach allPlayers;
            _ok
        };
        private _detectionLogged = false;
        if (!_skipDetectionWait) then {
            // Wait for first contact in zone or mission end (slow poll - not per-frame)
            waitUntil {
                sleep _pollInterval;
                if (call _taskDone) exitWith { true };
                private _in = call _playersInZone;
                if (_in && { !_detectionLogged }) then {
                    _detectionLogged = true;
                };
                _in
            };
            if (call _taskDone) exitWith {};
        } else {
            if (call _taskDone) exitWith {};
        };
        private _maxWaves = if (_ambientSingleWave) then { 1 } else { 1 + floor random 3 };
        private _firstDelaySec = _firstMin + random (_firstMax - _firstMin);
        sleep _firstDelaySec;

        private _waveFn = {
            params ["_taskId", "_objectivePos", "_enemyUnits", "_allGroups", "_numTrucks", "_applyGrp", "_pollInterval", "_detectionRadius"];
            private _sideEnemy = missionNamespace getVariable ["FADE_sideEnemy", east];
            private _pairs = [];
            {
                private _trig = missionNamespace getVariable [_x, objNull];
                if (!isNull _trig) then {
                    private _zc = getPosATL _trig;
                    if (count _zc >= 2) then {
                        _pairs pushBack [_zc distance2D _objectivePos, _zc];
                    };
                };
            } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
            if (count _pairs == 0) exitWith {};
            _pairs = [_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
            private _minBase = missionNamespace getVariable ["FADE_counterAttackMinDistFromBase", 1000];
            private _baseQ = FADE_basePos;
            private _roadPos = [];
            private _staging = [];
            private _stagingResolved = false;
            private _stCandidates = [];
            if (count _pairs >= 2) then { _stCandidates pushBack [1, (_pairs select 1) select 1] };
            if (count _pairs >= 3) then { _stCandidates pushBack [2, (_pairs select 2) select 1] };
            _stCandidates pushBack [0, (_pairs select 0) select 1];
            if (count _pairs >= 4) then { _stCandidates pushBack [3, (_pairs select 3) select 1] };
            private _nearOnly = (_pairs select 0) select 1;
            _stCandidates pushBack [-1, _nearOnly getPos [600 min ((_nearOnly distance2D _objectivePos) + 400), (_nearOnly getDir _objectivePos) + 180]];
            private _si = 0;
            while { _si < count _stCandidates && { !_stagingResolved } } do {
                private _st = (_stCandidates select _si) select 1;
                _staging = _st;
                if (count _staging < 3) then { _staging = [(_staging select 0), (_staging select 1), 0] };
                private _roadHit = [_staging, 450, [], _minBase, _baseQ, _objectivePos] call FADE_findOpforGroundVehicleRoadSpawn;
                if !(_roadHit isEqualTo []) then {
                    _roadHit params ["_roadPos", "_dir"];
                    _stagingResolved = true;
                };
                _si = _si + 1;
            };
            if (!_stagingResolved) then {
                private _dirFromBase = _baseQ getDir _objectivePos;
                private _fallbackPos = _baseQ getPos [(_minBase + 50), _dirFromBase];
                private _roadHit2 = [_fallbackPos, 250, [], _minBase, _baseQ, _objectivePos] call FADE_findOpforGroundVehicleRoadSpawn;
                if !(_roadHit2 isEqualTo []) then {
                    _roadHit2 params ["_roadPos", "_dir"];
                    _staging = _fallbackPos;
                    _stagingResolved = true;
                };
            };
            if (!_stagingResolved) exitWith {};
            if ((_roadPos isEqualType []) && { count _roadPos >= 2 } && { count _roadPos < 3 }) then {
                _roadPos = [(_roadPos select 0), (_roadPos select 1), 0];
            };
            private _flF = missionNamespace getVariable ["FADE_qrfSpawnHintFlare", {}];
            if (!(_flF isEqualTo {})) then { [_objectivePos, _detectionRadius] call _flF };
            private _anyPlayersInObjectiveZone = {
                private _ok = false;
                {
                    if (isPlayer _x && { alive _x } && { (_x distance2D _objectivePos) < _detectionRadius }) exitWith { _ok = true };
                } forEach allPlayers;
                _ok
            };
            private _huntQrf = !(call _anyPlayersInObjectiveZone);
            private _centF = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
            private _tgtMove = if (_huntQrf && {!(_centF isEqualTo {})}) then { [_objectivePos] call _centF } else { +_objectivePos };
            if (count _tgtMove < 3) then { _tgtMove = [(_tgtMove select 0), (_tgtMove select 1), 0] };
            private _dir = [_roadPos, _tgtMove] call BIS_fnc_dirTo;
            private _huntIv = (missionNamespace getVariable ["FADE_qrfHuntWaypointIntervalS", 60]) max 15;

            private _vehClasses = missionNamespace getVariable ["FADE_enemyVehicles", []];
            if (_vehClasses isEqualTo []) then {
                private _ef = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
                _vehClasses = [_ef] call FADE_getEnemyVehiclesForFaction;
            };
            private _soft = [];
            {
                if (!(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }) then {
                    if (!(_x isKindOf "Tank") && { !(_x isKindOf "Wheeled_APC_F") }) then { _soft pushBack _x };
                };
            } forEach _vehClasses;
            private _minCargo = missionNamespace getVariable ["FADE_counterAttackMinCargoSeats", 4];
            private _vehPick = [];
            private _softOk = [_soft, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            if (count _softOk > 0) then {
                _vehPick = _softOk;
            } else {
                private _landAll = _vehClasses select {
                    !(_x isKindOf "Air") && { !(_x isKindOf "Ship") } && { !(_x isKindOf "StaticWeapon") }
                };
                _vehPick = [_landAll, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _rhsFb = missionNamespace getVariable ["FADE_counterAttackRhsFallbacks", [
                    "rhs_gaz66_msv",
                    "rhs_zil131_msv",
                    "rhs_kamaz5350_msv",
                    "rhs_kamaz5350_open_msv",
                    "RHS_Ural_Civ_01",
                    "rhsgref_cdf_ural_open"
                ]];
                _vehPick = [_rhsFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) then {
                private _snCa = missionNamespace getVariable ["FADE_scenarioEnemySideNum", 0];
                private _vanFbDefault = switch (_snCa) do {
                    case 1: { ["B_Truck_01_transport_F", "B_T_Truck_01_transport_F", "I_Truck_02_transport_F", "O_Truck_02_transport_F"] };
                    case 2: { ["I_Truck_02_transport_F", "I_G_Offroad_01_transport_F", "O_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                    default { ["O_Truck_03_transport_F", "O_Truck_02_transport_F", "I_Truck_02_transport_F", "B_Truck_01_transport_F"] };
                };
                private _vanFb = missionNamespace getVariable ["FADE_counterAttackVanillaFallbacks", _vanFbDefault];
                _vehPick = [_vanFb, _minCargo] call FADE_counterAttack_filterClassesByMinCargo;
            };
            if (count _vehPick == 0) exitWith {
                private _sz = 4 + floor random 4;
                private _cls = (_enemyUnits select [0, _sz min count _enemyUnits]);
                for "_k" from (count _cls) to (_sz - 1) do { _cls pushBack (_enemyUnits select 0) };
                private _grp = [_roadPos, _sideEnemy, _cls] call BIS_fnc_spawnGroup;
                if (!isNull _grp && { count units _grp > 0 }) then {
                    [_grp] call _applyGrp;
                    _grp setBehaviour "COMBAT";
                    _grp setCombatMode "RED";
                    private _wp = _grp addWaypoint [_tgtMove, 0];
                    _wp setWaypointType "SAD";
                    _allGroups pushBack _grp;
                    if (_huntQrf) then {
                        [_grp, _taskId, _objectivePos, _huntIv] spawn {
                            params ["_grp", "_taskId", "_objectivePos", "_iv"];
                            private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                            private _td = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
                            while { !(isNull _grp) && { count units _grp > 0 } && { !(call _td) } } do {
                                sleep _iv;
                                if (isNull _grp || { count units _grp == 0 } || { call _td }) exitWith {};
                                private _p = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { +_objectivePos };
                                if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                                private _w = _grp addWaypoint [_p, 0];
                                _w setWaypointType "SAD";
                            };
                        };
                    };
                };
            };

            private _cargoStagger = missionNamespace getVariable ["FADE_counterAttackCargoStaggerSec", 0.35];
            private _spawnedVehs = [];
            private _roadHit = [];
            private _vClass = "";
            private _anchor = [0, 0, 0];
            private _spawnPos = [0, 0, 0];
            private _spawnDir = 0;
            private _vehGrp = grpNull;
            private _veh = objNull;
            private _driver = objNull;
            private _g = objNull;
            private _wpM = objNull;
            private _wpS = objNull;
            private _prev = objNull;
            for "_vi" from 0 to (_numTrucks - 1) do {
                if (_vi > 0) then { sleep 8 };
                _vClass = selectRandom _vehPick;
                _anchor = if (_vi == 0) then {
                    _roadPos
                } else {
                    _prev = _spawnedVehs select ((count _spawnedVehs) - 1);
                    if (isNull _prev) then { _roadPos } else { (getPosATL _prev) getPos [14, _dir + 180] }
                };
                _roadHit = [_anchor, 450, _spawnedVehs, _minBase, _baseQ, _tgtMove] call FADE_findOpforGroundVehicleRoadSpawn;
                if (_roadHit isEqualTo []) then { continue };
                _roadHit params ["_spawnPos", "_spawnDir"];
                if (_spawnPos distance2D _baseQ <= _minBase) then { continue };
                _vehGrp = createGroup _sideEnemy;
                _veh = createVehicle [_vClass, _spawnPos, [], 0, "NONE"];
                if (isNull _veh) then { deleteGroup _vehGrp; continue };
                _veh setPosATL _spawnPos;
                _veh setDir _spawnDir;
                _veh setVectorUp surfaceNormal _spawnPos;
                _veh setVelocity [(sin _dir) * 2, (cos _dir) * 2, 0];
                _veh engineOn true;
                _spawnedVehs pushBack _veh;
                [_taskId, _veh] call FADE_missionEnt_registerVehicle;
                _driver = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                if (!isNull _driver) then {
                    _driver moveInDriver _veh;
                    _vehGrp selectLeader _driver;
                };
                if (_veh emptyPositions "gunner" > 0) then {
                    _g = _vehGrp createUnit [selectRandom _enemyUnits, _spawnPos, [], 0, "NONE"];
                    if (!isNull _g) then { _g moveInGunner _veh };
                };
                [_vehGrp] call _applyGrp;
                _vehGrp setBehaviour "AWARE";
                _vehGrp setCombatMode "RED";
                _vehGrp setSpeedMode "NORMAL";
                _wpM = _vehGrp addWaypoint [_tgtMove, 25];
                _wpM setWaypointType "MOVE";
                _wpM setWaypointSpeed "NORMAL";
                _wpS = _vehGrp addWaypoint [_tgtMove, 0];
                _wpS setWaypointType "SAD";
                _allGroups pushBack _vehGrp;
                if (_huntQrf) then {
                    [_vehGrp, _veh, _taskId, _objectivePos, _huntIv] spawn {
                        params ["_vehGrp", "_veh", "_taskId", "_objectivePos", "_iv"];
                        private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                        private _td = { (_taskId call BIS_fnc_taskState) in ["SUCCEEDED", "CANCELED", "FAILED"] };
                        while { alive _veh && {!isNull _veh} && {!isNull _vehGrp} && { !(call _td) } } do {
                            sleep _iv;
                            if (!alive _veh || { isNull _veh } || { isNull _vehGrp }) exitWith {};
                            private _p = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { getPosATL _veh };
                            if (count _p < 3) then { _p = [(_p select 0), (_p select 1), 0] };
                            while { count waypoints _vehGrp > 0 } do { deleteWaypoint [_vehGrp, 0] };
                            private _wM = _vehGrp addWaypoint [_p, 25];
                            _wM setWaypointType "MOVE";
                            _wM setWaypointSpeed "NORMAL";
                            private _wS = _vehGrp addWaypoint [_p, 0];
                            _wS setWaypointType "SAD";
                        };
                    };
                };
                [_veh, _vehGrp, _enemyUnits, _applyGrp, _objectivePos, _pollInterval, _allGroups, _cargoStagger, _sideEnemy, _huntQrf, _taskId] spawn {
                    params ["_veh", "_vehGrp", "_enemyUnits", "_applyGrp", "_objectivePos", "_pollInterval", "_allGroups", "_cargoStagger", "_sideEnemy", "_huntQrf", "_taskId"];
                    private _cf = missionNamespace getVariable ["FADE_qrfFriendlyCentroidATL", {}];
                    private _seats = (_veh emptyPositions "cargo") max 0;
                    if (_seats <= 0) exitWith {};
                    private _cargoGrp = createGroup _sideEnemy;
                    for "_c" from 0 to (_seats - 1) do {
                        sleep _cargoStagger;
                        private _u = _cargoGrp createUnit [selectRandom _enemyUnits, getPosATL _veh, [], 0, "NONE"];
                        if (!isNull _u) then { _u moveInCargo _veh };
                    };
                    [_cargoGrp] call _applyGrp;
                    _allGroups pushBack _cargoGrp;
                    [_veh, _enemyUnits] call FADE_ensureEnemyVehicleGunner;
                    [_vehGrp] call _applyGrp;
                    waitUntil {
                        sleep _pollInterval;
                        if (!alive _veh || { isNull _veh }) then {
                            true
                        } else {
                            if (_huntQrf) then {
                                private _c = if (!(_cf isEqualTo {})) then { [_objectivePos] call _cf } else { +_objectivePos };
                                (_veh distance2D _c) < 140
                            } else {
                                (_veh distance2D _objectivePos) < 130
                            }
                        };
                    };
                    if (!alive _veh || { isNull _veh }) exitWith {};
                    if (!isNull _cargoGrp && { count units _cargoGrp > 0 }) then {
                        {
                            unassignVehicle _x;
                            _x action ["GetOut", _veh];
                        } forEach units _cargoGrp;
                        sleep 4;
                        _cargoGrp setBehaviour "COMBAT";
                        _cargoGrp setCombatMode "RED";
                        private _drop = if (_huntQrf && {!(_cf isEqualTo {})}) then { [_objectivePos] call _cf } else { +_objectivePos };
                        if (count _drop < 3) then { _drop = [(_drop select 0), (_drop select 1), 0] };
                        private _wp = _cargoGrp addWaypoint [_drop, 0];
                        _wp setWaypointType "SAD";
                    };
                };
            };
        };

        private _waveNum = 0;
        while { _waveNum < _maxWaves && { !(call _taskDone) } } do {
            _waveNum = _waveNum + 1;
            [_taskId, _objectivePos, _enemyUnits, _allGroups, _numTrucks, _applyGrp, _pollInterval, _detectionRadius] call _waveFn;
            if (call _taskDone) exitWith {};
            if (_waveNum >= _maxWaves) exitWith {};
            private _bw = _betMin + random (_betMax - _betMin);
            sleep _bw;
            if (call _taskDone) exitWith {};
            waitUntil {
                sleep _pollInterval;
                call _taskDone || { call _playersInZone }
            };
            if (call _taskDone) exitWith {};
        };
    };
};
missionNamespace setVariable ["FADE_counterAttackStart", FADE_counterAttackStart];

// Find mission position in urban areas only (civ zones). Returns [] if no civ zones.
// Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrban = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 100, _civZoneRadius, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Like findMissionPosUrban but keeps position near zone center (50â€“400 m) so we're in the built-up area.
// Use for mission types that need buildings (e.g. Hostage). Params: [["_minDistOverride", -1]]
FADE_findMissionPosUrbanNearCenter = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Find a road position within 200 m of a random civ zone (MissionTestSuite / tooling). Returns [] if none.
FADE_findMissionPosIED = {
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (_civZones isEqualTo []) exitWith { [] };
    private _base = FADE_basePos;
    private _minDist = FADE_minDistFromBase;
    private _result = [];
    for "_a" from 0 to 14 do {
        private _trig = missionNamespace getVariable [selectRandom _civZones, objNull];
        if (!isNull _trig) then {
            private _center = getPosATL _trig;
            if (count _center < 2) then { _center = [0,0,0] };
            if (_center distance _base < _minDist) then { continue };
            private _roads = _center nearRoads 200;
            if (_roads isEqualTo []) then { continue };
            private _road = selectRandom _roads;
            private _pos = getPosATL _road;
            if (count _pos >= 2 && { !(surfaceIsWater _pos) } && { _pos distance _base >= _minDist }) then {
                _result = [(_pos select 0), (_pos select 1), (_pos param [2, 0])];
            };
        };
        if (count _result >= 2) exitWith {};
    };
    _result
};
missionNamespace setVariable ["FADE_findMissionPosIED", FADE_findMissionPosIED];

// Asset Retrieval / Mine Clearing: position within _radiusM of a random civ zone center, at least _minDist from base.
// Params: [["_minDistOverride", -1], ["_radiusFromZone", 500]]
FADE_findMissionPosAssetRetrieval = {
    params [["_minDistOverride", -1], ["_radiusFromZone", 500]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];
    if (count _civZones == 0) exitWith { [] };
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _zoneName = selectRandom _civZones;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};
missionNamespace setVariable ["FADE_findMissionPosAssetRetrieval", FADE_findMissionPosAssetRetrieval];

// Find a valid mission position: near a civ zone centre, within 2.5km of zone center,
// at least _minDistOverride (or FADE_minDistFromBase) from base, clear ground, not on water.
// Params: [["_minDistOverride", -1]] - if > 0, use instead of FADE_minDistFromBase (e.g. 1000 for enemy missions)
FADE_findMissionPos = {
    params [["_minDistOverride", -1]];
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _civZoneRadius = 2500;
    private _result = [];
    private _attempt = 0;
    private _civZones = missionNamespace getVariable ["FADE_civTriggerNames", []];

    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [];
        if (count _civZones > 0) then {
            private _zoneName = selectRandom _civZones;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                _candidate = [[_zoneCenter, 100, _civZoneRadius, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            };
        };
        if (count _candidate < 2) then {
            private _x = _minXY + random (_maxXY - _minXY);
            private _y = _minXY + random (_maxXY - _minXY);
            _candidate = [_x, _y, 0];
            _candidate = [[_candidate, 0, 80, 5, 1, 0.5, 0, [], _candidate], _candidate] call FADE_findSafePosArray;
        };
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            private _sx = _candidate select 0;
            private _sy = _candidate select 1;
            if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                _result = _candidate;
            };
        };
    };
    _result
};

// Player map-click anchor: position within _radiusM of _anchor, min dist from base, clear ground.
FADE_findMissionPosNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) then { _radiusM = missionNamespace getVariable ["FADE_missionPlayerAnchorRadiusM", 2500] };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [[_anchor, 0, _radiusM, 5, 1, 0.5, 0, [], _anchor], _anchor] call FADE_findSafePosArray;
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            if ((_candidate distance2D _anchor) <= _radiusM) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

// Hostage: built-up spot 50â€“400 m from a civ zone centre, within _radiusM of _anchor (-1 = whole map).
FADE_findMissionPosUrbanNearCenterNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith { [_minDistOverride] call FADE_findMissionPosUrbanNearCenter };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        if (count _zoneNames == 0) exitWith {};
        private _zoneName = selectRandom _zoneNames;
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                if ((_candidate distance2D _anchor) <= _radiusM) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _result = _candidate;
                    };
                };
            };
        };
    };
    _result
};

FADE_findMissionPosUrbanNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith { [_minDistOverride] call FADE_findMissionPosUrban };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _result = [];
    private _attempt = 0;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        private _candidate = [];
        if (count _zoneNames > 0) then {
            private _zoneName = selectRandom _zoneNames;
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                _candidate = [[_zoneCenter, 50, 400, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            };
        };
        if (count _candidate < 2) then {
            private _c = [_minDistOverride] call FADE_findMissionPosUrban;
            if (count _c >= 2 && { (_c distance2D _anchor) <= _radiusM }) then { _candidate = _c };
        };
        if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
            if ((_candidate distance2D _anchor) <= _radiusM) then {
                private _sx = _candidate select 0;
                private _sy = _candidate select 1;
                if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                    _result = _candidate;
                };
            };
        };
    };
    _result
};

FADE_findMissionPosAssetRetrievalNearAnchor = {
    params ["_anchor", ["_minDistOverride", -1], ["_radiusFromZone", 500], ["_radiusM", -1]];
    if (count _anchor < 2) exitWith { [] };
    if (_radiusM < 0) exitWith {
        private _zoneNames = [];
        {
            private _trig = missionNamespace getVariable [_x, objNull];
            if (!isNull _trig) then {
                private _zc = getPosATL _trig;
                if (count _zc >= 2 && { (_zc distance _base) >= _minDist }) then {
                    _zoneNames pushBack _x;
                };
            };
        } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
        _zoneNames = [_zoneNames, [], {
            private _t = missionNamespace getVariable [_x, objNull];
            if (isNull _t) exitWith { 1e15 };
            (getPosATL _t) distance2D _anchor
        }, "ASCEND"] call BIS_fnc_sortBy;
        private _fallback = [];
        private _attempt = 0;
        while { _attempt < 25 && { count _fallback == 0 } } do {
            _attempt = _attempt + 1;
            if (count _zoneNames == 0) exitWith {};
            private _zoneName = _zoneNames select (_attempt mod count _zoneNames);
            private _trig = missionNamespace getVariable [_zoneName, objNull];
            if (!isNull _trig) then {
                private _zoneCenter = getPosATL _trig;
                private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
                if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _fallback = _candidate;
                    };
                };
            };
        };
        _fallback
    };
    private _base = FADE_basePos;
    private _minDist = if (_minDistOverride > 0) then { _minDistOverride } else { FADE_minDistFromBase };
    private _minXY = FADE_mapMin;
    private _maxXY = FADE_mapMax;
    private _zoneNames = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance2D _anchor) <= _radiusM } && { (_zc distance _base) >= _minDist }) then {
                _zoneNames pushBack _x;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    _zoneNames = [_zoneNames, [], {
        private _t = missionNamespace getVariable [_x, objNull];
        if (isNull _t) exitWith { 1e15 };
        (getPosATL _t) distance2D _anchor
    }, "ASCEND"] call BIS_fnc_sortBy;
    private _result = [];
    private _attempt = 0;
    while { _attempt < 25 && { count _result == 0 } } do {
        _attempt = _attempt + 1;
        if (count _zoneNames == 0) exitWith {};
        private _zoneName = _zoneNames select (_attempt mod count _zoneNames);
        private _trig = missionNamespace getVariable [_zoneName, objNull];
        if (!isNull _trig) then {
            private _zoneCenter = getPosATL _trig;
            private _candidate = [[_zoneCenter, 5, _radiusFromZone, 5, 1, 0.5, 0, [], _zoneCenter], _zoneCenter] call FADE_findSafePosArray;
            if (count _candidate >= 2 && { !(surfaceIsWater _candidate) } && { (_candidate distance _base) >= _minDist }) then {
                if ((_candidate distance2D _anchor) <= _radiusM) then {
                    private _sx = _candidate select 0;
                    private _sy = _candidate select 1;
                    if (_sx >= _minXY && { _sx <= _maxXY } && { _sy >= _minXY } && { _sy <= _maxXY }) then {
                        _result = _candidate;
                    };
                };
            };
        };
    };
    _result
};

// Civ zone names eligible for asset missions, sorted closest-first to map click (when valid).
FADE_fnc_assetZonesNearMapClick = {
    params ["_zoneNames", "_mapAnchor", ["_minDistFromBase", 1500], ["_resolvedRadius", -1]];
    private _out = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _zc = getPosATL _trig;
            if (count _zc >= 2 && { (_zc distance FADE_basePos) >= _minDistFromBase }) then {
                _out pushBack _x;
            };
        };
    } forEach _zoneNames;
    if (!([_mapAnchor] call FADE_fnc_isValidMapClickPos)) exitWith { _out };
    private _searchR = _resolvedRadius;
    private _snappedR = missionNamespace getVariable ["FADE_missionMapClickSnappedRadius", -2];
    if (_searchR != _snappedR && { _searchR >= 0 }) then {
        _out = _out select {
            private _t = missionNamespace getVariable [_x, objNull];
            !isNull _t && { (getPosATL _t distance2D _mapAnchor) <= _searchR }
        };
    };
    [_out, [], {
        private _t = missionNamespace getVariable [_x, objNull];
        if (isNull _t) exitWith { 1e15 };
        (getPosATL _t) distance2D _mapAnchor
    }, "ASCEND"] call BIS_fnc_sortBy
};

// Find a loose heli LZ hint near _center: dry land, moderate slope, no building/wall within clearance.
// Pilots are expected to choose the actual landing site nearby — not a pre-cleared pad.
// Params: [_center, _searchRadius] — search disc (default FADE_lzSearchRadiusDefault); each attempt jitters randomly within it.
// Returns: position array or [] if none found
FADE_findSafeLZ = {
    params ["_center", ["_searchRadius", -1]];
    if (count _center < 2) exitWith { [] };
    if (_searchRadius < 0) then {
        _searchRadius = missionNamespace getVariable ["FADE_lzSearchRadiusDefault", 80];
    };
    private _clearance = missionNamespace getVariable ["FADE_lzClearanceM", 5];
    private _maxGrad = missionNamespace getVariable ["FADE_lzMaxGrad", 0.5];
    private _maxAttempts = missionNamespace getVariable ["FADE_lzMaxAttempts", 30];
    private _localSearch = missionNamespace getVariable ["FADE_lzLocalSearchM", 25];
    private _objTypes = +(missionNamespace getVariable ["FADE_lzBlockObjectTypes", ["Building", "House", "Wall"]]);
    private _result = [];
    for "_attempt" from 1 to _maxAttempts do {
        private _tryCenter = if (_searchRadius < 1) then {
            +_center
        } else {
            [_center, random _searchRadius, random 360] call BIS_fnc_relPos
        };
        private _safe = [[_tryCenter, 0, _localSearch, _clearance, 0, _maxGrad, 0, [], _tryCenter], _tryCenter] call FADE_findLandPosWithArgs;
        if (count _safe < 2 || { surfaceIsWater _safe }) then { continue };
        private _blocking = nearestObjects [_safe, _objTypes, _clearance];
        if (({ !isNull _x } count _blocking) > 0) then { continue };
        _result = _safe;
    };
    _result
};

