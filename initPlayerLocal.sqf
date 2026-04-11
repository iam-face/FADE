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

// Mission-start client visual baseline.
setViewDistance 1500;
setTerrainGrid 25;

// Lobby params mirrored client-side for UI/action gating.
private _params = if (!isNil "paramsArray" && { paramsArray isEqualType [] }) then { paramsArray } else { [] };
missionNamespace setVariable ["FAC_param_missionsGuiAccess", _params param [0, missionNamespace getVariable ["FAC_param_missionsGuiAccess", 0]]];
missionNamespace setVariable ["FAC_param_scenarioGuiAccess", _params param [1, missionNamespace getVariable ["FAC_param_scenarioGuiAccess", 0]]];
missionNamespace setVariable ["FAC_param_enableAceArsenalActions", _params param [2, missionNamespace getVariable ["FAC_param_enableAceArsenalActions", 1]]];

FAC_playerHasLeaderOverrideAccess = {
    if (isNull player) exitWith { false };
    (serverCommandAvailable "#kick") || { !isNull (getAssignedCuratorLogic player) }
};
FAC_playerCanUseMissionsGui = {
    private _mode = missionNamespace getVariable ["FAC_param_missionsGuiAccess", 0];
    if (_mode <= 0) exitWith { true };
    (leader group player == player) || { call FAC_playerHasLeaderOverrideAccess }
};
FAC_playerCanUseScenarioGui = {
    private _mode = missionNamespace getVariable ["FAC_param_scenarioGuiAccess", 0];
    if (_mode <= 0) exitWith { true };
    (leader group player == player) || { call FAC_playerHasLeaderOverrideAccess }
};
FAC_playerCanTeleportToPlayers = {
    private _mode = missionNamespace getVariable ["FADE_teleportToPlayerMode", 0];
    if (_mode <= 0) exitWith { true };
    (leader group player == player) || { call FAC_playerHasLeaderOverrideAccess }
};

// -----------------------------------------------------------------------------
// Mission hints  - formatted hint (remoteExec from server: one player, or 0 = all clients with interface)
// -----------------------------------------------------------------------------
FADE_showMissionHint = {
    if (count _this > 0) then { hint parseText (_this select 0) };
};

// Server → evadee client: teleport to mission start position
FADE_clientTeleportPos = {
    params [["_pos", [0, 0, 0]]];
    if (!hasInterface) exitWith {};
    if (count _pos < 2) exitWith {};
    private _z = _pos param [2, 0];
    player setPosATL [(_pos select 0), (_pos select 1), _z];
};

// Server → evadee client: remove GPS (linked item) only
FADE_clientStripEvadeeGPS = {
    if (!hasInterface) exitWith {};
    if ("ItemGPS" in assignedItems player) then { player unlinkItem "ItemGPS" };
    player removeItem "ItemGPS";
};

// Dedicated MP: AI sideChat from server may not show on clients; local sideChat + client mirror (P15).
FADE_aiSideChat_exec = {
    params ["_unit", "_message"];
    if (isNull _unit || {!alive _unit}) exitWith {};
    if (local _unit) then {
        _unit sideChat _message;
    };
    if (hasInterface && {side player == side _unit}) then {
        if (!local _unit) then {
            systemChat _message;
        };
    };
};

// -----------------------------------------------------------------------------
// Scenario config sync  - server sends when Apply; client uses for Loadout/Vehicle GUIs
// -----------------------------------------------------------------------------
FADE_syncScenarioConfig = {
    params [["_friendlyFaction", "BLU_F"], ["_limitGear", false], ["_ctbOnly", false], ["_enemyFaction", "OPF_F"], ["_civFaction", "CIV_F"]];
    missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
    missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
    missionNamespace setVariable ["FADE_limitToCtbLoadouts", _ctbOnly];
    missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyFaction];
    missionNamespace setVariable ["FADE_scenarioCivFaction", _civFaction];
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

    private _apprehendSounds = ["FAC_apprehend001", "FAC_apprehend006", "FAC_apprehend011"];

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

// Load GUI scripts (LoadoutGui must compile even if CTB data file breaks — CTB presets load lazily when that tab is chosen)
call compile preprocessFileLineNumbers "rsc\LoadoutGui.sqf";
// Respawn snapshot: capture Eden slot / JIP loadout early (before long waitUntil / death) if not yet saved (loadout box overwrites).
[] spawn {
    sleep 0.3;
    [player] call FAC_loadoutGui_trySaveInitialRespawnLoadoutIfMissing;
};
call compile preprocessFileLineNumbers "rsc\VehicleGui.sqf";
call compile preprocessFileLineNumbers "rsc\FiresArtilleryList.sqf";
call compile preprocessFileLineNumbers "rsc\FiresFallOfShot.sqf";
call compile preprocessFileLineNumbers "rsc\FiresGui.sqf";
call compile preprocessFileLineNumbers "rsc\MedicalTrainingKAT_fractureLocal.sqf";
call compile preprocessFileLineNumbers "rsc\MedicalTrainingGui.sqf";
call compile preprocessFileLineNumbers "rsc\EscapeEvasionPickGui.sqf";
call compile preprocessFileLineNumbers "rsc\MissionsGui.sqf";
call compile preprocessFileLineNumbers "rsc\ScenarioGui.sqf";
missionNamespace setVariable ["FAC_scenarioGui_fnc", FAC_scenarioGui_fnc];
call compile preprocessFileLineNumbers "rsc\JukeboxGui.sqf";
missionNamespace setVariable ["FAC_jukeboxGui_fnc", FAC_jukeboxGui_fnc];
missionNamespace setVariable ["FAC_jukebox_clientPlay", FAC_jukebox_clientPlay];
missionNamespace setVariable ["FAC_jukebox_clientStopAll", FAC_jukebox_clientStopAll];
missionNamespace setVariable ["FAC_jukebox_serverDbgChat", FAC_jukebox_serverDbgChat];
missionNamespace setVariable ["FAC_jukebox_fnc_addVehicleLoudspeakerAction", FAC_jukebox_fnc_addVehicleLoudspeakerAction];
missionNamespace setVariable ["FAC_jukebox_fnc_installVehicleLoudspeakerHandlers", FAC_jukebox_fnc_installVehicleLoudspeakerHandlers];

// Jukebox 3D audio: no JIP replay — replaying from FAC_jukebox_activeSources on connect caused extra playSound3D starts (heard as random restarts on dedicated).

// CQB pop-up targets: server triggers this on all clients so knock-down is visible in MP.
// animateSource errors if the source name is missing on this model — walk CfgVehicles inheritance (leg hits etc. use same path).
FADE_cqbClient_forceTargetDown = {
    params [["_t", objNull]];
    if (isNull _t) exitWith {};
    private _v = _t;
    {
        private _src = _x;
        private _c = configFile >> "CfgVehicles" >> (typeOf _v);
        private _ok = false;
        while { isClass _c && { !_ok } } do {
            if (isClass (_c >> "AnimationSources" >> _src)) then { _ok = true };
            if (!_ok) then { _c = inheritsFrom _c };
        };
        if (_ok) then { _v animateSource [_src, 1, true]; };
    } forEach ["terc", "popup_Source", "popup_hide", "Target_Up_Source"];
};
call compile preprocessFileLineNumbers "rsc\CQBGui.sqf";
call compile preprocessFileLineNumbers "rsc\SniperGui.sqf";
call compile preprocessFileLineNumbers "rsc\RangeGui.sqf";
call compile preprocessFileLineNumbers "rsc\CqbLoudspeaker.sqf";
call compile preprocessFileLineNumbers "rsc\TeleportGui.sqf";

// After server/client actions from board GUIs, refresh any open dialog (same as header Refresh) after a short delay.
FAC_guiScheduleHeaderRefresh = {
    params [["_delay", 0.4]];
    [_delay] spawn {
        params ["_delay"];
        sleep _delay;
        private _veh = missionNamespace getVariable ["FAC_vehicleGui_fnc", {}];
        private _miss = missionNamespace getVariable ["FAC_missionsGui_fnc", {}];
        private _scen = missionNamespace getVariable ["FAC_scenarioGui_fnc", {}];
        private _load = missionNamespace getVariable ["FAC_loadoutGui_fnc", {}];
        private _juke = missionNamespace getVariable ["FAC_jukeboxGui_fnc", {}];
        private _cqb = missionNamespace getVariable ["FAC_cqbGui_fnc", {}];
        private _tp = missionNamespace getVariable ["FAC_teleportGui_fnc", {}];
        private _fires = missionNamespace getVariable ["FAC_firesGui_fnc", {}];
        private _medTr = missionNamespace getVariable ["FAC_medicalTrainingGui_fnc", {}];
        private _sniper = missionNamespace getVariable ["FAC_sniperGui_fnc", {}];
        private _range = missionNamespace getVariable ["FAC_rangeGui_fnc", {}];
        if (!isNull (findDisplay 60001)) then { ["headerRefresh", []] call _veh };
        if (!isNull (findDisplay 60002)) then { ["headerRefresh", []] call _miss };
        if (!isNull (findDisplay 60003)) then { ["headerRefresh", []] call _scen };
        if (!isNull (findDisplay 60200)) then { ["headerRefresh", []] call _load };
        if (!isNull (findDisplay 60400)) then { ["headerRefresh", []] call _juke };
        if (!isNull (findDisplay 60500)) then { ["headerRefresh", []] call _cqb };
        if (!isNull (findDisplay 60600)) then { ["headerRefresh", []] call _tp };
        if (!isNull (findDisplay 60610)) then { ["headerRefreshPlayers", []] call _tp };
        if (!isNull (findDisplay 60700)) then { ["headerRefresh", []] call _fires };
        if (!isNull (findDisplay 60800)) then { ["headerRefresh", []] call _medTr };
        if (!isNull (findDisplay 60910)) then { ["headerRefresh", []] call _sniper };
        if (!isNull (findDisplay 60920)) then { ["headerRefresh", []] call _range };
    };
};
missionNamespace setVariable ["FAC_guiScheduleHeaderRefresh", FAC_guiScheduleHeaderRefresh];

waitUntil {
    sleep 0.1;
    !isNil "FADE_heliClasses" && !isNil "FADE_boards" && !isNil "FADE_loadoutBox" && !isNil "FADE_cqbBoard"
};

FAC_addScenarioActionToTerminal = {
    params ["_obj", ["_priority", 2.5]];
    if (isNull _obj) exitWith {};
    _obj addAction [
        "<t color='#87CEEB'>Manage Scenario</t>",
        {
            if !(call FAC_playerCanUseScenarioGui) exitWith {
                systemChat "Scenario GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { sleep 0.2; ["open", []] call FAC_scenarioGui_fnc };
        },
        [],
        _priority,
        false,
        true,
        "",
        "",
        3
    ];
};

// Request scenario config from server (limit gear, friendly faction) for Loadout/Vehicle GUIs
[player] remoteExec ["FADE_sendScenarioConfigToClient", 2];

// FIRES fall-of-shot: clear stale client drone-screen state after JIP / load (no briefing RTT)
[] spawn {
    sleep 1.5;
    if (!hasInterface) exitWith {};
    [player] remoteExec ["FADE_firesFoS_requestSync", 2];
};

// Firing / AT range: terminalRange (human + vehicle targets, AT weapon slots)
[] spawn {
    sleep 0.35;
    private _rangeTerm = missionNamespace getVariable ["FADE_terminalRange", objNull];
    if (isNull _rangeTerm) then { _rangeTerm = missionNamespace getVariable ["terminalRange", objNull] };
    if (isNull _rangeTerm) exitWith {};
    removeAllActions _rangeTerm;
    _rangeTerm addAction [
        "<t color='#FFA45B'>Firing and AT range</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_rangeGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    [_rangeTerm, 2] call FAC_addScenarioActionToTerminal;
};

// Manage Vehicles: terminalVeh when present; else vehBoard (vehBoard keeps vehicles2.jpg texture on initServer)
private _vehicleGuiObj = missionNamespace getVariable ["FADE_vehicleTerminal", objNull];
if (isNull _vehicleGuiObj) then { _vehicleGuiObj = missionNamespace getVariable ["FADE_vehicleBoard", objNull] };
if (!isNull _vehicleGuiObj) then {
    removeAllActions _vehicleGuiObj;
    _vehicleGuiObj addAction [
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

// FIRES terminal (terminalFires): artillery spawn / rearm / despawn at firesPos_* logic objects
private _firesTerm = missionNamespace getVariable ["FADE_firesTerminal", objNull];
if (!isNull _firesTerm) then {
    removeAllActions _firesTerm;
    _firesTerm addAction [
        "<t color='#FFAA66'>FIRES range</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_firesGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    [_firesTerm, 2] call FAC_addScenarioActionToTerminal;
};

// Medical training terminal (terminalMedical): dummy spawn / injuries / heal
private _medTerm = missionNamespace getVariable ["FADE_medicalTrainingTerminal", objNull];
if (!isNull _medTerm) then {
    removeAllActions _medTerm;
    _medTerm addAction [
        "<t color='#66DDCC'>Medical training</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_medicalTrainingGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    [_medTerm, 2] call FAC_addScenarioActionToTerminal;
};

// Missions/Config board (missionBoard): Manage Missions + Manage Scenario
private _missionBoard = missionNamespace getVariable ["FADE_missionBoard", objNull];
if (!isNull _missionBoard) then {
    removeAllActions _missionBoard;
    _missionBoard addAction [
        "<t color='#FFD700'>Manage Missions</t>",
        {
            if !(call FAC_playerCanUseMissionsGui) exitWith {
                systemChat "Missions GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { sleep 0.2; ["open", []] call FAC_missionsGui_fnc };
        },
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
        {
            if !(call FAC_playerCanUseScenarioGui) exitWith {
                systemChat "Scenario GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { sleep 0.2; ["open", []] call FAC_scenarioGui_fnc };
        },
        [],
        3,
        false,
        true,
        "",
        "",
        3
    ];
};

// Sniper range: resolve Eden name + synced var (JIP); short delay so other inits / MP sync do not strip the action
[] spawn {
    sleep 0.35;
    private _sniperTerm = missionNamespace getVariable ["FADE_sniperTerminal", objNull];
    if (isNull _sniperTerm) then { _sniperTerm = missionNamespace getVariable ["terminalSniper", objNull] };
    if (isNull _sniperTerm) exitWith {};
    removeAllActions _sniperTerm;
    _sniperTerm addAction [
        "<t color='#B8A0FF'>Sniper range</t>",
        { [] spawn { sleep 0.2; ["open", []] call FAC_sniperGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    [_sniperTerm, 2] call FAC_addScenarioActionToTerminal;
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
    [_cqbBoard, 2] call FAC_addScenarioActionToTerminal;
};

// Teleport boards (teleportBoard_1..9) - opens Fast Travel GUI.
// Each board preselects its matching destination in the GUI.
private _teleportBoardMap = [
    ["teleportBoard_1", "teleportBase"],
    ["teleportBoard_2", "teleportOfficer"],
    ["teleportBoard_3", "teleportPad3"],
    ["teleportBoard_4", "teleportRange"],
    ["teleportBoard_5", "teleportCQB"],
    ["teleportBoard_6", "teleportPad1"],
    ["teleportBoard_7", "teleportLockerRoom"],
    ["teleportBoard_8", "teleportSDE"],
    ["teleportBoard_9", "teleportFires"]
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
                [player] call FAC_loadoutGui_saveRespawnLoadoutSnapshot;
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
            if ((missionNamespace getVariable ["FAC_param_enableAceArsenalActions", 1]) > 0) then {
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

// Jukebox: Vehicle loudspeaker UI on the *player unit* only (local addAction / ACE self — not on vehicle hull)
[player] call FAC_jukebox_fnc_addVehicleLoudspeakerAction;
[player] call FAC_jukebox_fnc_installVehicleLoudspeakerHandlers;

// SDE's bar: Nesk_1 (Eden name) - drink interaction (local player only; lethal)
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

// Welcome hint  - replaces loading hint when config and actions are ready (briefing + GUIs hold full detail)
private _playerName = name player;
private _welcomeText = format [
    "<t size='1.25' color='#FFD700'>[FADE] FACE'S DYNAMIC ENVIRONMENT</t><br/><br/>" +
    "<t align='left'>" +
    "<t color='#FFFFFF'>Welcome, </t><t color='#FFCC00'>%1</t><t color='#FFFFFF'>!</t><br/><br/>" +
    "<t color='#00FF00'>CTB Headquarters</t><t color='#FFFFFF'> has vehicles, missions, scenario, gear, music, teleportation.</t><br/>" +
    "<t color='#FFFFFF'>Visit </t><t color='#FFCC00'>Rhodesy's office</t><t color='#FFFFFF'> to manage scenario, mission and admin settings.</t><br/>" +
    "<t color='#FFFFFF'>Visit </t><t color='#FFCC00'>MB's gear room</t><t color='#FFFFFF'> for loadouts and kit.</t><br/><br/>" +
    "<t color='#FFCC00'>Other key locations include</t><t color='#FFFFFF'> Bean's Medical area, Joon's FIRES range, Sultan's CQB facility, Sniper, Rifle and AT ranges, SDE's pub, Juko's locker room, C3 Quiet Area, and other training spots around base.</t><br/>" +
    "<t color='#FFCC00'>Quick-reference CTB Doctrine callouts</t><t color='#FFFFFF'> are located in your notes.</t><br/>" +
    "<t color='#FFCC00'>SMEACs</t><t color='#FFFFFF'> are generated when started pre-defined mission types (from Rhodesy's office or via mission hotkey).</t><br/>" +
    "<t color='#FFCC00'>Ctrl + ;</t><t color='#FFFFFF'> opens the Mission GUI from anywhere.</t><br/>" +
    "<t color='#FFCC00'>Ctrl + Shift + 'apostrophe'</t><t color='#FFFFFF'> (quotation mark) opens Fast Travel from anywhere.</t><br/>" +
    "" +
    "<t color='#FFFFFF'>Remember: Do not take SDE's STANAGS.</t>" +
    "</t>",
    _playerName
];
hint parseText _welcomeText;

// Invisible ambient lights 25m above each helipad and vehicle spawn
[] spawn { execVM "rsc\LightTowers.sqf" };

// Full heal near HQ (FADE_basePos from BASE_1): poll, local player only (40s reduces idle client wakeups)
[] spawn {
    if (!hasInterface) exitWith {};
    waitUntil { sleep 0.5; count (missionNamespace getVariable ["FADE_basePos", []]) >= 2 };
    private _radius = 50;
    private _interval = missionNamespace getVariable ["FADE_hqHealIntervalSec", 40];
    if (_interval < 15) then { _interval = 15 };
    while { true } do {
        sleep _interval;
        private _u = player;
        if (alive _u && {local _u}) then {
            private _hq = missionNamespace getVariable ["FADE_basePos", []];
            if (
                (count _hq >= 2)
                && {(getPosATL _u) distance2D [_hq select 0, _hq select 1] <= _radius}
            ) then {
                _u setDamage 0;
                _u setFatigue 0;
                if ((getBleedingRemaining _u) > 0) then { _u setBleedingRemaining 0 };
                if (!isNil "ace_medical_fnc_fullHeal") then { _u call ace_medical_fnc_fullHeal };
            };
        };
    };
};

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
                [_this select 0] call FAC_vehicleGui_tryOpenPylonDialog;
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
// KeyDown on main display (46): Ctrl+; = Missions GUI; Ctrl+Shift+apostrophe = Fast Travel
// displayAddEventHandler runs on the client; findDisplay 46 is the game HUD.
// Teleport uses DIK_APOSTROPHE (0x28) + _shift + _ctrl (same chord as typing " on US QWERTY).
// RCtrl-only tracking via DIK 0x9D was unreliable (flag never set on some setups), so either Ctrl works.
// -----------------------------------------------------------------------------
[] spawn {
    waitUntil { !isNull findDisplay 46 };
    (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        // CTRL+; (DIK_SEMICOLON = 0x27)  - open Missions GUI from anywhere
        if (_key == 0x27 && { _ctrl }) exitWith {
            if !(call FAC_playerCanUseMissionsGui) exitWith {
                systemChat "Missions GUI is restricted to group leaders (admin/Zeus override).";
                true
            };
            if (isNull (findDisplay 60002)) then {
                ["open", []] call FAC_missionsGui_fnc;
            };
            true
        };
        // Ctrl+Shift+apostrophe: Fast Travel / Teleport GUI (same as teleport boards)
        if (_key == 0x28 && { _shift } && { _ctrl }) exitWith {
            if (isNull (findDisplay 60600) && { isNull (findDisplay 60610) }) then {
                ["open", []] call FAC_teleportGui_fnc;
            };
            true
        };
        false
    }];
};

// Mission test suite — manual only. Debug console: [] call FAC_missionTestSuite_execClient  |  server: [player] remoteExec ["FAC_missionTestSuite_execServer", 2]
FAC_missionTestSuite_execClient = {
    if (!hasInterface) exitWith {};
    if (isNil "FAC_missionTestSuite_runClient") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    private _res = call FAC_missionTestSuite_runClient;
    if (!(isNil "_res") && { count _res >= 2 }) then {
        _res params ["_p", "_f"];
        systemChat format ["[FAC TestSuite] Client finished: %1 pass, %2 fail — see RPT for [FAC TestSuite].", _p, _f];
    } else {
        systemChat "[FAC TestSuite] Client: aborted (script error — check RPT).";
    };
};
