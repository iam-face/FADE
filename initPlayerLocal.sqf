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
call compile preprocessFileLineNumbers "rsc\FAC_MissionTypeLabels.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_IntelClient.sqf";

// Debug: optional BIS campaign function stubs - default off in Config (see rsc\DebugBIScpStub.sqf)
call compile preprocessFileLineNumbers "rsc\DebugBIScpStub.sqf";

if (isNil "FADE_baseNpc_clientSetIdentity") then {
    call compile preprocessFileLineNumbers "rsc\BaseNpcTalk.sqf";
};
if (isNil "FAC_baseNpc_registered_pvh") then {
    FAC_baseNpc_registered_pvh = "FADE_baseNpc_registered" addPublicVariableEventHandler {
        if (!hasInterface) exitWith {};
        [] spawn { sleep 0.5; [] call FADE_baseNpc_clientEnsureInteract };
    };
};

// Mission-start client visual baseline.
setViewDistance 1500;
setTerrainGrid 25;

// Lobby params mirrored client-side for UI/action gating.
call compile preprocessFileLineNumbers "rsc\FAC_LobbyParams.sqf";

// -----------------------------------------------------------------------------
// Mission hints  - formatted hint (remoteExec from server: one player, or 0 = all clients with interface)
// -----------------------------------------------------------------------------
FADE_showMissionHint = {
    if (count _this > 0) then { hint parseText (_this select 0) };
};

// Per-player local pickup marker for Troop Insert (visible only on this client).
// Server remoteExecs these to the owning player so other players don't see the marker.
FAC_troopInsertClient_createPickupMarker = {
    params [["_mkrName", ""], ["_pos", [0, 0, 0]], ["_label", "Squad link-up"], ["_color", "ColorWEST"]];
    if (!hasInterface) exitWith {};
    if (_mkrName isEqualTo "") exitWith {};
    if (getMarkerColor _mkrName != "") then { deleteMarkerLocal _mkrName };
    private _m = createMarkerLocal [_mkrName, _pos];
    _m setMarkerTypeLocal "mil_pickup";
    _m setMarkerColorLocal _color;
    _m setMarkerTextLocal _label;
};
FAC_troopInsertClient_deletePickupMarker = {
    params [["_mkrName", ""]];
    if (!hasInterface) exitWith {};
    if (_mkrName isEqualTo "") exitWith {};
    if (getMarkerColor _mkrName != "") then { deleteMarkerLocal _mkrName };
};

// initServer still sends the starter name as arg 2 for compatibility; subtitle uses mission type from synced state.
FADE_resolveAssignedIntroMissionTypeId = {
    params ["_operationNameUpper"];
    private _tid = player getVariable ["FADE_myMission", ""];
    if (_tid isEqualTo "") then {
        private _g = missionNamespace getVariable ["FADE_globalMission", []];
        if (count _g >= 5 && { toUpper (_g select 4) == _operationNameUpper }) then { _tid = _g select 0 };
    };
    if (_tid isEqualTo "") then {
        {
            if (count _x >= 5 && { toUpper (_x select 4) == _operationNameUpper }) exitWith { _tid = _x select 0 };
        } forEach (missionNamespace getVariable ["FADE_singleMissions", []]);
    };
    _tid
};

// Mission assigned: typeText title + mission type (full SMEAC stays on BI Task only)
// BIS_fnc_typeText (Arma 3): spawn as [_stringLines] or [_stringLines, posX, posY, rootFormat] — NOT _stringLines
// alone, or params mis-reads line 2 as posX/posY and shows the literal format token (e.g. "PLAIN DOWN").
// Each line is [text, structuredFormatWith%1, blinkCount]; only `text` is typed — wrapper stays valid XML.
FADE_showMissionAssignedIntro = {
    params ["_operationName", "_legacyStarterName"];
    if (!hasInterface) exitWith {};
    private _tid = [_operationName] call FADE_resolveAssignedIntroMissionTypeId;
    private _missionTypeLabel = if !(_tid isEqualTo "") then {
        [_tid] call (missionNamespace getVariable ["FADE_missionTypeDisplayName", { params ["_id"]; _id }])
    } else {
        "Mission"
    };
    private _lineByPlain = _missionTypeLabel;
    private _taskHint = parseText "<t color='#E0E0E0'>Read your <t color='#FFCC00'>Task</t> panel for the full SMEAC.</t>";
    private _fmtTitle = "<t align='center' shadow='1' size='1.15' font='PuristaBold' color='#FFD700'>%1</t><br/>";
    private _fmtSub = "<t align='center' shadow='1' size='0.9' color='#D0D0D0'>%1</t><br/>";
    private _lines = [
        [_operationName, _fmtTitle, 5],
        [_lineByPlain, _fmtSub, 5]
    ];
    if (isNil "BIS_fnc_typeText") exitWith {
        hint parseText format [
            "<t align='center' size='1.4' font='PuristaBold' color='#FFD700'>%1</t><br/><br/><t align='center' size='0.95' color='#D0D0D0'>%2</t><br/><br/><t color='#E0E0E0'>Read your <t color='#FFCC00'>Task</t> panel for the full SMEAC.</t>",
            _operationName,
            _missionTypeLabel
        ];
    };
    private _holdSec = 4;
    [_lines, _taskHint, _operationName, _missionTypeLabel, _holdSec] spawn {
        params ["_lines", "_taskHint", "_operationName", "_missionTypeLabel", "_holdSec"];
        private _h = [_lines] spawn BIS_fnc_typeText;
        waitUntil { sleep 0.05; scriptDone _h };
        // typeText exits quickly after cursor blinks; hold the same two lines ~_holdSec s before SMEAC hint.
        // titleText: plain String shows raw <t> markup on-screen; parseText was rejected as wrong type for titleText in RPT.
        // hint parseText matches FADE_showMissionHint and renders structured text correctly.
        private _holdParsed = parseText format [
            "<t align='center' shadow='1' size='1.15' font='PuristaBold' color='#FFD700'>%1</t><br/><t align='center' shadow='1' size='0.9' color='#D0D0D0'>%2</t>",
            _operationName,
            _missionTypeLabel
        ];
        hint _holdParsed;
        sleep _holdSec;
        hint _taskHint;
    };
};

// Server → evadee client: teleport to mission start position; optional dir (deg) e.g. face toward town
FADE_clientTeleportPos = {
    params [["_pos", []], ["_dir", -1]];
    if (!hasInterface) exitWith {};
    if (!(_pos isEqualType []) || { count _pos < 2 }) exitWith {};
    private _x = _pos select 0;
    private _y = _pos select 1;
    if (!finite _x || {!finite _y}) exitWith {};
    private _z = _pos param [2, 0];
    if (!finite _z) then { _z = 0 };
    player setPosATL [_x, _y, _z];
    if (_dir >= 0) then { player setDir _dir };
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
    params [["_friendlyFaction", "BLU_F"], ["_limitGear", false], ["_presetOnly", false], ["_enemyFaction", "OPF_F"], ["_civFaction", "CIV_F"], ["_civTalkInterpretersOnly", false], ["_intelSpecialistsOnly", false]];
    missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
    missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
    missionNamespace setVariable ["FADE_limitToPresetLoadouts", _presetOnly];
    missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyFaction];
    missionNamespace setVariable ["FADE_scenarioCivFaction", _civFaction];
    missionNamespace setVariable ["FADE_civTalkInterpretersOnly", _civTalkInterpretersOnly];
    missionNamespace setVariable ["FADE_intelSpecialistsOnly", _intelSpecialistsOnly];
};

// -----------------------------------------------------------------------------
// Loading hint  - shown immediately whilst config and actions load
// -----------------------------------------------------------------------------
hint "FADE LOADING...";

// Diary + reference subjects early (Intel tab must exist before civilian HUMINT can append during play).
call compile preprocessFileLineNumbers "rsc\Briefing.sqf";

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

// Lazy GUI loaders — compile dialogs on first open (rsc\FAC_ClientGuiEnsure.sqf) for faster lobby → map.
private _iplEnsureT = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };
call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf";
if (_iplEnsureT >= 0) then {
    diag_log format ["[FAC profile] compile FAC_ClientGuiEnsure.sqf: %1 s", diag_tickTime - _iplEnsureT];
};

// Respawn snapshot: capture Eden slot / JIP loadout early (LoadoutGui compiles inside spawn).
[] spawn {
    sleep 0.3;
    call FAC_ensureLoadoutGui;
    [player] call FAC_loadoutGui_trySaveInitialRespawnLoadoutIfMissing;
};

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

// After server/client actions from board GUIs, refresh any open dialog (same as header Refresh) after a short delay.
FAC_guiScheduleHeaderRefresh = {
    params [["_delay", 0.4]];
    [_delay] spawn {
        params ["_delay"];
        sleep _delay;
        if (!isNull (findDisplay 60001)) then { call FAC_ensureVehicleGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_vehicleGui_fnc") };
        if (!isNull (findDisplay 60002)) then { call FAC_ensureMissionsGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_missionsGui_fnc") };
        if (!isNull (findDisplay 60003)) then { call FAC_ensureScenarioGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_scenarioGui_fnc") };
        if (!isNull (findDisplay 60200)) then { call FAC_ensureLoadoutGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_loadoutGui_fnc") };
        if (!isNull (findDisplay 60400)) then { call FAC_ensureJukeboxGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_jukeboxGui_fnc") };
        if (!isNull (findDisplay 60500)) then { call FAC_ensureCQBGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_cqbGui_fnc") };
        if (!isNull (findDisplay 60600)) then { call FAC_ensureTeleportGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_teleportGui_fnc") };
        if (!isNull (findDisplay 60610)) then { call FAC_ensureTeleportGui; ["headerRefreshPlayers", []] call (missionNamespace getVariable "FAC_teleportGui_fnc") };
        if (!isNull (findDisplay 60700)) then { call FAC_ensureFiresGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_firesGui_fnc") };
        if (!isNull (findDisplay 60800)) then { call FAC_ensureMedicalTrainingGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_medicalTrainingGui_fnc") };
        if (!isNull (findDisplay 60910)) then { call FAC_ensureSniperGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_sniperGui_fnc") };
    };
};
missionNamespace setVariable ["FAC_guiScheduleHeaderRefresh", FAC_guiScheduleHeaderRefresh];

private _iplT0 = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };
waitUntil {
    sleep (if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { 0.05 } else { 0.1 });
    missionNamespace getVariable ["FADE_clientInitReady", false]
};
if (_iplT0 >= 0) then {
    diag_log format ["[FAC profile] client waitUntil FADE_clientInitReady: %1 s", diag_tickTime - _iplT0];
};

// Server remoteExec hooks (CQB loudspeaker, cutscene RTT) — keep loaded once past mission sync; not full GUI stack.
call compile preprocessFileLineNumbers "rsc\CqbLoudspeaker.sqf";
call compile preprocessFileLineNumbers "rsc\CutsceneClient.sqf";

call FAC_ensureJukeboxGui;
call FAC_ensureCivTalkGui;

// JIP / late connect: add Talk action on already-spawned ambient civilians + base NPC (netId may arrive after CivTalkGui loads).
[] spawn {
    if (!hasInterface) exitWith {};
    private _delays = [1, 2, 4, 8, 15];
    {
        sleep _x;
        call FAC_ensureCivTalkGui;
        private _fn = missionNamespace getVariable ["FADE_civTalk_addLocalAction", {}];
        if (_fn isEqualType {}) then {
            {
                if (alive _x && {
                    _x getVariable ["FADE_ambientCiv", false] || { _x getVariable ["FADE_baseNpcTalk", false] }
                }) then { [_x] call _fn };
            } forEach allUnits;
        };
        private _refresh = missionNamespace getVariable ["FADE_civTalk_refreshBaseNpcAction", {}];
        if (_refresh isEqualType {}) then { [] call _refresh };
        if (!isNil "FADE_baseNpc_clientEnsureInteract") then { [] call FADE_baseNpc_clientEnsureInteract };
    } forEach _delays;
};

FAC_addScenarioActionToTerminal = {
    params ["_obj", ["_priority", 2.5]];
    if (isNull _obj) exitWith {};
    _obj addAction [
        "<t color='#87CEEB'>Manage Scenario</t>",
        {
            if !(["FAC_playerCanUseScenarioGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Scenario GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { call FAC_ensureScenarioGui; sleep 0.2; ["open", []] call FAC_scenarioGui_fnc };
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
        { [] spawn { call FAC_ensureRangeGui; sleep 0.2; ["open", []] call FAC_rangeGui_fnc } },
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
        {
            if !(["FAC_playerCanUseVehicleGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Vehicle GUI access denied by lobby settings.";
            };
            [] spawn { call FAC_ensureVehicleGui; sleep 0.2; ["open", []] call FAC_vehicleGui_fnc };
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

// Client: FIRES timed drill grid/elev hint (remoteExec from server)
FADE_fires_drill_clientNotify = {
    params ["_title", "_grid", "_elev", "_slotLabel"];
    private _t = format [
        "<t color='#FFD700' size='1.05'>%1</t><br/><t color='#AAAAAA'>%4</t><br/>Grid: <t color='#90EE90'>%2</t><br/>Elev (ASL ~): %3 m<br/><t color='#87CEEB'>Timer started at target spawn.</t>",
        _title,
        _grid,
        _elev,
        _slotLabel
    ];
    hint parseText _t;
};

// Client: FIRES timed drill completion hint (server remoteExecs to the starter only; systemChat is global in FiresDrillServer)
FADE_fires_drill_clientCompleteHint = {
    params [["_html", ""]];
    if (!hasInterface) exitWith {};
    hint parseText _html;
};

// FIRES terminal (terminalFires): artillery spawn / rearm / despawn at firesPos_* logic objects
private _firesTerm = missionNamespace getVariable ["FADE_firesTerminal", objNull];
if (!isNull _firesTerm) then {
    removeAllActions _firesTerm;
    _firesTerm addAction [
        "<t color='#FFAA66'>FIRES range</t>",
        { [] spawn { call FAC_ensureFiresGui; sleep 0.2; ["open", []] call FAC_firesGui_fnc } },
        [],
        5,
        false,
        true,
        "",
        "",
        3
    ];
    if (isClass (configFile >> "CfgPatches" >> "ace_arsenal")) then {
        if ((missionNamespace getVariable ["FAC_param_enableAceArsenalActions", 1]) > 0) then {
            _firesTerm addAction [
                "<t color='#FF8C00'>Open ACE Arsenal</t>",
                { [(_this select 0), (_this select 1)] call ace_arsenal_fnc_openBox },
                [],
                4.5,
                false,
                true,
                "",
                "",
                3
            ];
        };
    };
    [_firesTerm, 2] call FAC_addScenarioActionToTerminal;
};

// Medical training terminal (terminalMedical): dummy spawn / injuries / heal
private _medTerm = missionNamespace getVariable ["FADE_medicalTrainingTerminal", objNull];
if (!isNull _medTerm) then {
    removeAllActions _medTerm;
    _medTerm addAction [
        "<t color='#66DDCC'>Medical training</t>",
        { [] spawn { call FAC_ensureMedicalTrainingGui; sleep 0.2; ["open", []] call FAC_medicalTrainingGui_fnc } },
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
            if !(["FAC_playerCanUseMissionsGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Missions GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { call FAC_ensureMissionsGui; sleep 0.2; ["open", []] call FAC_missionsGui_fnc };
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
            if !(["FAC_playerCanUseScenarioGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Scenario GUI is restricted to group leaders (admin/Zeus override).";
            };
            [] spawn { call FAC_ensureScenarioGui; sleep 0.2; ["open", []] call FAC_scenarioGui_fnc };
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
        { [] spawn { call FAC_ensureSniperGui; sleep 0.2; ["open", []] call FAC_sniperGui_fnc } },
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
        { [] spawn { call FAC_ensureCQBGui; sleep 0.2; ["open", []] call FAC_cqbGui_fnc } },
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
                call FAC_ensureTeleportGui;
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

// Add loadout actions to all loadout boxes (Manage My Loadout, Save loadout, ACE Arsenal). Run after short delay so we run after ACE/other inits that may strip actions.
[] spawn {
    sleep 0.5;
    call FAC_ensureLoadoutGui;
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
            {
                if !(["FAC_playerCanUseLoadoutGui"] call FAC_lobbyParams_callAccess) exitWith {
                    systemChat "Loadout GUI access denied by lobby settings.";
                };
                [] spawn { call FAC_ensureLoadoutGui; sleep 0.2; ["open", []] call FAC_loadoutGui_fnc };
            },
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
                if !(["FAC_playerCanUseLoadoutGui"] call FAC_lobbyParams_callAccess) exitWith {
                    systemChat "Loadout GUI access denied by lobby settings.";
                };
                call FAC_ensureLoadoutGui;
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
            if ((missionNamespace getVariable ["FAC_param_enableAceArsenalActions", 1]) > 0 && { ["FAC_playerCanUseLoadoutGui"] call FAC_lobbyParams_callAccess }) then {
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
                if !(["FAC_playerCanUseJukebox"] call FAC_lobbyParams_callAccess) exitWith {
                    systemChat "Jukebox access denied by lobby settings.";
                };
                missionNamespace setVariable ["FAC_jukebox_guiSource", _args select 0];
                [] spawn { call FAC_ensureJukeboxGui; sleep 0.2; ["open", []] call FAC_jukeboxGui_fnc };
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

// Locker Room -- hostage VO + locker slaps (game logic posLockerRoom + posLocker_*); see rsc\Config.sqf
[] execVM "rsc\LockerRoomAmbient.sqf";

// Welcome hint  - replaces loading hint when config and actions are ready (briefing + GUIs hold full detail)
private _playerName = name player;
private _welcomeText = format [
    "<t size='1.25' color='#FFD700'>[FADE] FACE'S DYNAMIC ENVIRONMENT</t><br/><br/>" +
    "<t align='left'>" +
    "<t color='#FFFFFF'>Welcome, </t><t color='#FFCC00'>%1</t><t color='#FFFFFF'>!</t><br/><br/>" +
    "<t color='#FF0000'>Base Headquarters</t><t color='#FFFFFF'> has vehicles, missions, scenario, gear, music, teleportation.</t><br/>" +
    "<t color='#FFFFFF'>Visit </t><t color='#FFCC00'>Rhodesy's office</t><t color='#FFFFFF'> to manage scenario, mission and admin settings.</t><br/>" +
    "<t color='#FFFFFF'>Visit </t><t color='#FFCC00'>MB's gear room</t><t color='#FFFFFF'> for loadouts and kit.</t><br/><br/>" +
    "<t color='#FFCC00'>Other key locations include</t><t color='#FFFFFF'> Bean's Medical area, Joon's FIRES range, Sultan's CQB facility, Sniper, Rifle and AT ranges, SDE's pub, Juko's locker room, C3 Quiet Area, and other training spots around base.</t><br/>" +
    "<t color='#FFCC00'>Quick-reference Doctrine callouts</t><t color='#FFFFFF'> are located in your notes.</t><br/>" +
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
    if ((missionNamespace getVariable ["FAC_param_hqAutoHeal", 1]) <= 0) exitWith {};
    private _radius = 50;
    private _interval = missionNamespace getVariable ["FADE_hqHealIntervalSec", 40];
    if (_interval <= 0) exitWith {};
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
                call FAC_ensureVehicleGui;
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
            if !(["FAC_playerCanUseMissionsGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Missions GUI is restricted to group leaders (admin/Zeus override).";
                true
            };
            if (isNull (findDisplay 60002)) then {
                call FAC_ensureMissionsGui;
                ["open", []] call FAC_missionsGui_fnc;
            };
            true
        };
        // Ctrl+Shift+apostrophe: Fast Travel / Teleport GUI (same as teleport boards)
        if (_key == 0x28 && { _shift } && { _ctrl }) exitWith {
            if (isNull (findDisplay 60600) && { isNull (findDisplay 60610) }) then {
                call FAC_ensureTeleportGui;
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
