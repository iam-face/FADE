// ServerWorldEden.sqf - Eden refs, boards, fires/CQB terminals, base pos, ambient hooks
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
// Music board next to base radios (non-interactable)
[missionNamespace getVariable ["musicBoard", objNull], "img\sigsound.jpg"] call _applyBoardTexture;
// Base radio props (jukebox interaction via FAC_ClientBoardActions on Radio_1..4)
[missionNamespace getVariable ["Radio_1", objNull], "img\sigsound.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_2", objNull], "img\sigsound.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_3", objNull], "img\sigsound.jpg"] call _applyBoardTexture;
[missionNamespace getVariable ["Radio_4", objNull], "img\sigsound.jpg"] call _applyBoardTexture;
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
