// =============================================================================
// initPlayerLocal.sqf  - Face's Dynamic Sandbox client init (board actions)
// =============================================================================
//
// DEDICATED SERVER CONSIDERATIONS:
// - This file runs ONLY on clients (players). The server does not execute it.
// - cursorObject / cursorTarget are client-side; they return what the local
//   player is looking at. The server cannot determine this.
// - remoteExec [..., 2] sends to server (2 = server machine ID). The server
//   must have FAC_surrenderChallenge_start publicVariable'd and the function
//   defined. JIP players get publicVariable on connect.
// =============================================================================

// Debug: set true to show systemChat for every key interaction (cursorTarget, cursorObject, etc.)
FAC_surrenderChallenge_debugKeys = false;

// Debug: stub missing BIS campaign functions to log caller (set FADE_debugBIScp = false to disable)
call compile preprocessFileLineNumbers "rsc\DebugBIScpStub.sqf";

// -----------------------------------------------------------------------------
// Mission hints  - formatted hint shown only to the targeted player (called via remoteExec from server)
// -----------------------------------------------------------------------------
FADE_showMissionHint = {
    if (count _this > 0) then { hint parseText (_this select 0) };
};

// -----------------------------------------------------------------------------
// Scenario config sync  - server sends when Apply; client uses for Loadout/Vehicle GUIs
// -----------------------------------------------------------------------------
FADE_syncScenarioConfig = {
    params [["_friendlyFaction", "BLU_F"], ["_limitGear", false]];
    missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
    missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
};

// -----------------------------------------------------------------------------
// Loading hint  - shown immediately whilst config and actions load
// -----------------------------------------------------------------------------
hint "LOADING AO...";

// -----------------------------------------------------------------------------
// Surrender Challenge  - activation function (runs on client when key pressed)
// -----------------------------------------------------------------------------
FAC_surrenderChallenge_fnc_activate = {
    private _dbg = { if (missionNamespace getVariable ["FAC_surrenderChallenge_debugKeys", false]) then { systemChat _this } };

    "U pressed  - Surrender Challenge" call _dbg;

    // Early exit if player is dead  - avoids null/invalid target issues
    if (!alive player) exitWith {
        "[FAC] Abort: Player dead." call _dbg;
    };

    // cursorObject can return the weapon mesh when aiming at a soldier (known Arma quirk).
    // cursorTarget returns the unit but requires knowsAbout for enemies. Try both, then
    // resolve weapon->unit via attachedTo or nearestObjects.
    private _target = cursorTarget;
    (format ["cursorTarget: %1 (Man:%2)", if (isNull _target) then {"null"} else {typeOf _target}, if (!isNull _target) then {str (_target isKindOf "Man")} else {"n/a"}]) call _dbg;

    if (isNull _target || {!(_target isKindOf "Man")}) then {
        _target = cursorObject;
        (format ["cursorObject: %1 (Man:%2)", if (isNull _target) then {"null"} else {typeOf _target}, if (!isNull _target) then {str (_target isKindOf "Man")} else {"n/a"}]) call _dbg;
    };
    // If cursorObject returned a weapon/proxy, try attachedTo or find nearest Man
    if (!isNull _target && {!(_target isKindOf "Man")}) then {
        private _attached = attachedTo _target;
        if (!isNull _attached && {_attached isKindOf "Man"}) then {
            _target = _attached;
            "[FAC] Resolved via attachedTo -> Man" call _dbg;
        } else {
            private _pos = getPosATL _target;
            private _near = nearestObjects [_pos, ["Man"], 2];
            if (count _near > 0) then {
                _target = _near select 0;
                (format ["[FAC] Resolved via nearestObjects (%1 Man within 2m)", count _near]) call _dbg;
            } else {
                _target = objNull;
                "[FAC] nearestObjects found no Man within 2m" call _dbg;
            };
        };
    };

    if (isNull _target) exitWith {
        systemChat "NO TARGET. ACQUIRE HOSTILE.";
        "[FAC] Exit: No valid target." call _dbg;
        diag_log "[FAC SurrenderChallenge] Client: No target (cursorObject/cursorTarget null)";
    };

    // Must be infantry  - excludes vehicles, static weapons, animals
    if (!(_target isKindOf "Man")) exitWith {
        systemChat "TARGET MUST BE PERSONNEL.";
        (format ["[FAC] Exit: Target not Man (type: %1)", typeOf _target]) call _dbg;
        diag_log "[FAC SurrenderChallenge] Client: Target not Man: " + (typeOf _target);
    };

    if (_target == player) exitWith {
        "[FAC] Exit: Ignored (targeted self)" call _dbg;
        diag_log "[FAC SurrenderChallenge] Client: Ignored (player targeted self)";
    };

    // Play challenge shout from player  - random fac_apprehend sound, 3D so target/nearby hear it
    private _apprehendSounds = ["FAC_apprehend001", "FAC_apprehend006", "FAC_apprehend011", "FAC_apprehend018", "FAC_apprehend024", "FAC_apprehend032", "FAC_apprehend043", "FAC_apprehend050"];
    private _chosen = selectRandom _apprehendSounds;
    [player, [_chosen, 80, 1]] remoteExec ["say3D", 0];

    // remoteExec to server (2). Pass player dir so server can validate 30° cone.
    [player, _target, getDir player] remoteExec ["FAC_surrenderChallenge_start", 2];

    (format ["[FAC] SENT: Challenge for %1 (dist %2m)", name _target, round (player distance _target)]) call _dbg;
    diag_log "[FAC SurrenderChallenge] Client: Challenge sent for " + (name _target);
};

// Load GUI scripts
call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";
call compile preprocessFileLineNumbers "rsc\VehicleGui.sqf";
call compile preprocessFileLineNumbers "rsc\MissionsGui.sqf";
call compile preprocessFileLineNumbers "rsc\ScenarioGui.sqf";
call compile preprocessFileLineNumbers "rsc\JukeboxGui.sqf";
call compile preprocessFileLineNumbers "rsc\CQBGui.sqf";
call compile preprocessFileLineNumbers "rsc\TeleportGui.sqf";

waitUntil { !isNil "FADE_heliClasses" && !isNil "FADE_boards" && !isNil "FADE_loadoutBox" && !isNil "FADE_cqbBoard" };

// Request scenario config from server (limit gear, friendly faction) for Loadout/Vehicle GUIs
[player] remoteExec ["FADE_sendScenarioConfigToClient", 2];

// Vehicle board (vehBoard): Manage Vehicles only
private _vehicleBoard = missionNamespace getVariable ["FADE_vehicleBoard", objNull];
if (!isNull _vehicleBoard) then {
    removeAllActions _vehicleBoard;
    _vehicleBoard addAction [
        "<t color='#00FF00'>Manage Vehicles</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_vehicleGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
};

// Missions/Config board (missionBoard): Manage Missions + Manage Scenario
private _missionBoard = missionNamespace getVariable ["FADE_missionBoard", objNull];
if (!isNull _missionBoard) then {
    removeAllActions _missionBoard;
    _missionBoard addAction [
        "<t color='#FFD700'>Manage Missions</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_missionsGui_fnc } },
        [],
        4,
        false,
        true,
        "",
        "",
        3
    ];
    _missionBoard addAction [
        "<t color='#87CEEB'>Manage Scenario</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_scenarioGui_fnc } },
        [],
        3,
        false,
        true,
        "",
        "",
        3
    ];
};

// CQB Training Shoothouse board (cqbBoard) — opens CQB GUI
if (!isNull (missionNamespace getVariable ["FADE_cqbBoard", objNull])) then {
    private _cqbBoard = missionNamespace getVariable "FADE_cqbBoard";
    removeAllActions _cqbBoard;
    _cqbBoard addAction [
        "<t color='#FFA500'>CQB Training</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_cqbGui_fnc } },
        [],
        4,
        false,
        true,
        "",
        "",
        3
    ];
};

// Teleport boards (teleportBoard_1..7) — opens Fast Travel GUI
{
    private _board = missionNamespace getVariable [_x, objNull];
    if (isNull _board) then { continue };
    removeAllActions _board;
    _board addAction [
        "<t color='#00FFFF'>Fast Travel</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_teleportGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
} forEach ["teleportBoard_1", "teleportBoard_2", "teleportBoard_3", "teleportBoard_4", "teleportBoard_5", "teleportBoard_6", "teleportBoard_7"];

// In-game briefing and diary (map screen: Briefing + Notes, incl. 9-Line JTAC)
execVM "rsc\Briefing.sqf";

// Add loadout actions to all loadout boxes (Manage My Loadout, Save loadout, ACE Arsenal). Run after short delay so we run after ACE/other inits that may strip actions.
[] spawn {
    sleep 0.5;
    private _boxes = missionNamespace getVariable ["FADE_loadoutBoxes", []];
    if (_boxes isEqualTo [] && { !isNull (missionNamespace getVariable ["FADE_loadoutBox", objNull]) }) then {
        _boxes = [missionNamespace getVariable "FADE_loadoutBox"];
        if (!isNull (missionNamespace getVariable ["FADE_loadoutBox2", objNull])) then { _boxes pushBack (missionNamespace getVariable "FADE_loadoutBox2") };
    };
    {
        private _box = _x;
        if (isNull _box) then { continue };
        removeAllActions _box;
        _box addAction [
            "<t color='#00BFFF'>Manage My Loadout</t>",
            { [] spawn { sleep 0.2; ["open", []] call FAC_loadoutGui_fnc } },
            [],
            6,
            false,
            true,
            "",
            "",
            3
        ];
        _box addAction [
            "<t color='#98FB98'>Save my loadout</t>",
            {
                private _uid = getPlayerUID player;
                missionNamespace setVariable ["FAC_savedLoadout_" + _uid, getUnitLoadout player];
                systemChat "Loadout saved - will be restored on respawn.";
            },
            [],
            5.5,
            false,
            true,
            "",
            "",
            3
        ];
        if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
            _box addAction [
                "<t color='#FF8C00'>Open ACE Arsenal</t>",
                { [(_this select 0), (_this select 1)] call ace_arsenal_fnc_openBox },  // target, caller
                [],
                5,
                false,
                true,
                "",
                "",
                3
            ];
        };
    } forEach _boxes;
};

// Add Radio_1 jukebox action  - Radio_1 is an Eden-named object (missionNamespace)
private _radio = missionNamespace getVariable ["Radio_1", objNull];
if (!isNull _radio) then {
    _radio addAction [
        "<t color='#FF69B4'>Jukebox</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_jukeboxGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
};

// Locker room  - optional Eden object LOCKER_1; play sound on use (add Sounds\locker_slap.ogg or uses fallback)
private _locker = missionNamespace getVariable ["LOCKER_1", objNull];
if (!isNull _locker) then {
    _locker addAction [
        "<t color='#DDA0DD'>Locker room</t>",
        {
            playSound "FAC_LockerSlap";
            systemChat "Locker room.";
        },
        [],
        4,
        false,
        true,
        "",
        "",
        3
    ];
};

// Welcome hint  - replaces loading hint when config and actions are ready
private _playerName = name player;
private _welcomeText = format [
    "<t size='1.3' color='#FFD700'>FACE'S DYNAMIC ENVIRONMENT</t><t size='0.85' color='#888888'> (FADE)</t><br/>" +
    "<t size='0.9' color='#888888'>──────────────────────────────</t><br/>" +
    "<t color='#E0E0E0'>Welcome, </t><t color='#FFCC00'>%1</t><t color='#E0E0E0'>!</t><br/><br/>" +

    "<t size='1.05' color='#FFD700'>QUICK START</t><br/>" +
    "<t color='#AAAAAA'>  1. </t><t color='#00FF00'>BOARD</t><t color='#C0C0C0'> -> Manage Vehicles -> spawn an aircraft</t><br/>" +
    "<t color='#AAAAAA'>  2. </t><t color='#00FF00'>BOARD</t><t color='#C0C0C0'> -> Manage Missions -> select and start a mission</t><br/>" +
    "<t color='#AAAAAA'>  3. </t><t color='#C0C0C0'>Fly to the marked objective and complete the task</t><br/><br/>" +

    "<t size='1.05' color='#FFD700'>AT BASE</t><br/>" +
    "<t color='#00FF00'>  BOARD</t><t color='#C0C0C0'>  - Vehicles , Missions , Scenario (time, weather, factions)</t><br/>" +
    "<t color='#00BFFF'>  LOADOUT BOX</t><t color='#C0C0C0'>  - Customise kit , ACE Arsenal (if loaded)</t><br/>" +
    "<t color='#FF69B4'>  RADIO</t><t color='#C0C0C0'>  - Jukebox</t><br/><br/>" +

    "<t size='1.05' color='#FFD700'>KEYBINDS</t><br/>" +
    "<t color='#FFCC00'>  CTRL+;</t><t color='#C0C0C0'>  - Manage Missions from anywhere</t><br/>" +
    "<t color='#FFCC00'>  U</t><t color='#C0C0C0'>  - Surrender Challenge (aim at enemy, press)</t><br/>" +
    "<t color='#FFCC00'>  M</t><t color='#C0C0C0'>  - Map, Briefing, CAS/JTAC notes &amp; procedures</t><br/><br/>" +

    "<t size='1.05' color='#FFD700'>MISSION TYPES</t><br/>" +
    "<t color='#C0C0C0'>  Troop Insert , Troop Extract , CAS , Cargo</t><br/>" +
    "<t color='#C0C0C0'>  HVT , Hostage , Clear Area , Intercept Convoy</t><br/><br/>" +

    "<t size='0.85' color='#666666'>Open the map (M) -> Scenario Brief for full overview and procedures.</t>",
    _playerName
];
hint parseText _welcomeText;

// Invisible ambient lights 25m above each helipad and vehicle spawn
[] spawn { execVM "rsc\LightTowers.sqf" };

// Pilot pylon management: when player is driver of a vehicle with pylons, add action to open vehicle customization (pylon loadout)
FAC_pylonActionId = -1;
FAC_pylonActionVeh = objNull;
player addEventHandler ["GetInMan", {
    params ["_unit", "_role", "_veh", "_turret"];
    if (_role != "driver") exitWith {};
    if (!isNil "FAC_pylonActionVeh" && { FAC_pylonActionVeh isEqualTo _veh } && { FAC_pylonActionId >= 0 }) exitWith {};
    if (!isNil "FAC_pylonActionId" && { FAC_pylonActionId >= 0 } && { !isNull FAC_pylonActionVeh }) then { FAC_pylonActionVeh removeAction FAC_pylonActionId; };
    FAC_pylonActionVeh = objNull;
    FAC_pylonActionId = -1;
    if (count getAllPylonsInfo _veh > 0) then {
        FAC_pylonActionId = _veh addAction [
            "<t color='#87CEEB'>Manage pylons (vehicle loadout)</t>",
            {
                (vehicle (_this select 1)) action ["VehicleCustomization", vehicle (_this select 1)];
            },
            [],
            0,
            false,
            true,
            "",
            "driver _target == _this",
            4
        ];
        FAC_pylonActionVeh = _veh;
    };
}];
player addEventHandler ["GetOutMan", {
    params ["_unit", "_role", "_veh", "_turret"];
    if (!isNil "FAC_pylonActionVeh" && { FAC_pylonActionVeh isEqualTo _veh } && { !isNil "FAC_pylonActionId" } && { FAC_pylonActionId >= 0 }) then {
        _veh removeAction FAC_pylonActionId;
        FAC_pylonActionId = -1;
        FAC_pylonActionVeh = objNull;
    };
}];

// -----------------------------------------------------------------------------
// KeyDown on main display (46): U = Surrender Challenge, L = Missions GUI
// displayAddEventHandler runs on the client; findDisplay 46 is the game HUD.
// -----------------------------------------------------------------------------
[] spawn {
    waitUntil { !isNull findDisplay 46 };
    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        // CTRL+; (DIK_SEMICOLON = 0x27)  - open Missions GUI from anywhere
        if (_key == 0x27 && { _ctrl }) exitWith {
            if (isNull (findDisplay 60002)) then {
                ["open", []] call FAC_missionsGui_fnc;
            };
            true
        };
        // DIK_U = 0x16  - Surrender Challenge
        if (_key == 0x16) then {
            if (time - (missionNamespace getVariable ["FAC_surrenderChallenge_lastTrigger", 0]) > 1.5) then {
                missionNamespace setVariable ["FAC_surrenderChallenge_lastTrigger", time];
                [] spawn FAC_surrenderChallenge_fnc_activate;
            };
        };
        false
    }];
};

// -----------------------------------------------------------------------------
// Surrender Challenge: inputAction fallback  - for custom-bound keys
// inputAction returns > 0 when key is held. Poll every 0.15s.
// FAC_SurrenderChallenge = CfgUserActions; User1 = generic user action.
// -----------------------------------------------------------------------------
[] spawn {
    private _lastTrigger = 0;
    while { true } do {
        sleep 0.15;
        if (inputAction "FAC_SurrenderChallenge" > 0 || { inputAction "User1" > 0 }) then {
            if (time - _lastTrigger > 1.5) then {
                _lastTrigger = time;
                [] spawn FAC_surrenderChallenge_fnc_activate;
            };
        };
    };
};
