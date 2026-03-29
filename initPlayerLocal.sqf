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
// - Surrender Challenge: player path disabled (see FAC_surrenderChallenge_playerEnabled on server).
// =============================================================================

// Debug: set true to show systemChat for every key interaction (cursorTarget, cursorObject, etc.)
FAC_surrenderChallenge_debugKeys = false;

// Config (same as server) so FADE_* flags e.g. FADE_debugBIScp apply before optional BIS CP stubs
call compile preprocessFileLineNumbers "rsc\Config.sqf";

// Debug: optional BIS campaign function stubs - default off in Config (see rsc\DebugBIScpStub.sqf)
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
// Surrender Challenge  - client activation (unused while FAC_surrenderChallenge_playerEnabled is false)
// With no Man under cursor: still plays apprehend shout + server timed sequence (no AI).
// -----------------------------------------------------------------------------
FAC_surrenderChallenge_fnc_activate = {
    if (!(missionNamespace getVariable ["FAC_surrenderChallenge_playerEnabled", false])) exitWith {};

    private _dbg = { if (missionNamespace getVariable ["FAC_surrenderChallenge_debugKeys", false]) then { systemChat _this } };

    // Early exit if player is dead  - avoids null/invalid target issues
    if (!alive player) exitWith {
        "[FAC] Abort: Player dead." call _dbg;
    };

    // Min 2s between uses when player path is enabled (legacy: U key / inputAction / CfgUserActions)
    if (time - (missionNamespace getVariable ["FAC_surrenderChallenge_lastTrigger", 0]) < 2) exitWith {};
    missionNamespace setVariable ["FAC_surrenderChallenge_lastTrigger", time];

    "U pressed  - Surrender Challenge" call _dbg;

    private _apprehendSounds = ["FAC_apprehend001", "FAC_apprehend006", "FAC_apprehend011", "FAC_apprehend018", "FAC_apprehend024", "FAC_apprehend032", "FAC_apprehend043", "FAC_apprehend050"];

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
        private _chosen = selectRandom _apprehendSounds;
        [player, [_chosen, 500, 1, 2]] remoteExec ["say3D", 0];
        [player, objNull, getDir player] remoteExec ["FAC_surrenderChallenge_start", 2];
        "[FAC] Sent: no-target (practice) challenge" call _dbg;
        diag_log "[FAC SurrenderChallenge] Client: No target - practice challenge";
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
    private _chosen = selectRandom _apprehendSounds;
    [player, [_chosen, 500, 1, 2]] remoteExec ["say3D", 0];

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
missionNamespace setVariable ["FAC_jukeboxGui_fnc", FAC_jukeboxGui_fnc];
missionNamespace setVariable ["FAC_jukebox_clientPlay", FAC_jukebox_clientPlay];
missionNamespace setVariable ["FAC_jukebox_serverDbgChat", FAC_jukebox_serverDbgChat];

// JIP: replay all active jukebox sources (server maintains FAC_jukebox_activeSources)
[] spawn {
    uiSleep 0.75;
    private _st = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
    {
        _x params ["_k", "_s"];
        if (_s != "") then { [_s, _k] call FAC_jukebox_clientPlay };
    } forEach _st;
};
call compile preprocessFileLineNumbers "rsc\CQBGui.sqf";
call compile preprocessFileLineNumbers "rsc\CqbLoudspeaker.sqf";
call compile preprocessFile "rsc\TeleportGui.sqf";

waitUntil {
    sleep 0.05;
    !isNil "FADE_heliClasses" && !isNil "FADE_boards" && !isNil "FADE_loadoutBox" && !isNil "FADE_cqbBoard"
};

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

// CQB Training Shoothouse board (cqbBoard) - opens CQB GUI
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

// Teleport boards (teleportBoard_1..8) - opens Fast Travel GUI.
// Each board preselects its matching destination in the GUI.
private _teleportBoardMap = [
    ["teleportBoard_1", "BASE_1"],
    ["teleportBoard_2", "MEDICAL_1"],
    ["teleportBoard_3", "HP_4"],
    ["teleportBoard_4", "firingRangeBoard"],
    ["teleportBoard_5", "cqbBoard"],
    ["teleportBoard_6", "VEH_2"],
    ["teleportBoard_7", "teleportBoard_7"],
    ["teleportBoard_8", "teleportBoard_8"]
];
{
    _x params ["_boardName", "_defaultDest"];
    private _board = missionNamespace getVariable [_boardName, objNull];
    if (isNull _board) then { continue };
    removeAllActions _board;
    _board addAction [
        "<t color='#00FFFF'>Fast Travel</t>",
        {
            params ["_target", "_caller", "_actionId", "_args"];
            _args params [["_defaultDest", ""]];
            [_defaultDest] spawn {
                params ["_defaultDest"];
                sleep 0.2;
                ["open", [_defaultDest]] call FAC_teleportGui_fnc
            };
        },
        [_defaultDest],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    _board addAction [
        "<t color='#88DDFF'>Teleport to Map Location</t>",
        { execVM "rsc\TeleportMapPick.sqf" },
        [],
        4,
        false,
        true,
        "",
        "",
        3
    ];
} forEach _teleportBoardMap;

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

// Jukebox: Radio_1..Radio_4 (Eden names); each source gets its own playback slot
{
    private _eden = _x;
    private _key = format ["radio:%1", _eden];
    private _radio = missionNamespace getVariable [_eden, objNull];
    if (!isNull _radio) then {
        _radio addAction [
            "<t color='#FF69B4'>Jukebox</t>",
            {
                params ["_target", "_caller", "_actionId", "_args"];
                missionNamespace setVariable ["FAC_jukebox_guiSource", _args select 0];
                [] spawn { sleep 0.2; ["open", []] call FAC_jukeboxGui_fnc };
            },
            [_key],
            5,
            false,
            true,
            "",
            "",
            3
        ];
    };
} forEach ["Radio_1", "Radio_2", "Radio_3", "Radio_4"];

// SDE's bar: Nesk_1 (Eden name) — drink interaction (local player only; lethal)
private _nesk = missionNamespace getVariable ["Nesk_1", objNull];
if (!isNull _nesk) then {
    removeAllActions _nesk;
    _nesk addAction [
        "Drink the Neskwhiskey",
        {
            params ["_target", "_caller", "_actionId", "_args"];
            if (missionNamespace getVariable ["FAC_neskWhiskeyInProgress", false]) exitWith {};
            missionNamespace setVariable ["FAC_neskWhiskeyInProgress", true];
            [_caller] spawn {
                params ["_unit"];
                if (isNull _unit || {!alive _unit} || {!local _unit}) exitWith {
                    missionNamespace setVariable ["FAC_neskWhiskeyInProgress", false];
                };
                _unit switchMove "Acts_Stunned_Unconscious";
                sleep 7;
                if (alive _unit && {local _unit}) then {
                    _unit setDamage 1;
                };
                missionNamespace setVariable ["FAC_neskWhiskeyInProgress", false];
            };
        },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
};

// CTB Locker Room -- hostage VO + locker slaps (game logic posLockerRoom + posLocker_*); see rsc\Config.sqf
[] execVM "rsc\LockerRoomAmbient.sqf";

// Welcome hint  - replaces loading hint when config and actions are ready (keep short: briefing + GUIs hold detail)
private _playerName = name player;
private _welcomeText = format [
    "<t size='1.25' color='#FFD700'>[FADE] FACE'S DYNAMIC ENVIRONMENT</t><br/><br/>" +
    "<t align='left'>" +
    "<t color='#FFFFFF'>Welcome, </t><t color='#FFCC00'>%1</t><t color='#FFFFFF'>!</t><br/><br/>" +
    "<t color='#00FF00'>Base Boards</t><t color='#FFFFFF'> have vehicles, missions, scenario, gear, teleportation.</t><br/>" +
    "<t color='#FFCC00'>CTB Doctrine</t><t color='#FFFFFF'> callouts are located in your notes.</t><br/>" +
    "<t color='#FFCC00'>Ctrl + ;</t><t color='#FFFFFF'> opens the Mission GUI from anywhere.</t><br/>" +
    "<t color='#FFCC00'>Ctrl + '</t><t color='#FFFFFF'> opens the Jukebox (music from your character).</t><br/><br/>" +
    "<t color='#FFFFFF'>Remember: Do not take SDE's STANAGS.</t>" +
    "</t>",
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
// KeyDown on main display (46): Ctrl+; = Missions GUI, Ctrl+' = Jukebox
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
        // CTRL+' (DIK_APOSTROPHE = 0x28) - Jukebox (sound from player)
        if (_key == 0x28 && { _ctrl }) exitWith {
            if (isNull (findDisplay 60400)) then {
                missionNamespace setVariable ["FAC_jukebox_guiSource", format ["player:%1", getPlayerUID player]];
                [] spawn { sleep 0.05; ["open", []] call FAC_jukeboxGui_fnc };
            };
            true
        };
        false
    }];
};
