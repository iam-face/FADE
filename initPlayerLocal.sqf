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

// Config (client subset) so FADE_* flags e.g. FADE_debugBIScp apply before optional BIS CP stubs
call compile preprocessFileLineNumbers "rsc\ConfigClient.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_MissionTypeLabels.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_ClientCommon.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_MissionSlots.sqf";
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
call compile preprocessFileLineNumbers "rsc\FAC_LobbyParamsDebugPatch.sqf";
call FAC_lobbyParams_read;

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
    params ["_operationName", "_legacyStarterName", ["_loreShort", ""]];
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
    // Lore headline: hint only — BIS_fnc_typeText corrupts a third line (format %1 vs long text).
    private _lines = [
        [_operationName, _fmtTitle, 5],
        [_lineByPlain, _fmtSub, 5]
    ];
    private _escapeFmt = missionNamespace getVariable ["FADE_lore_escapeForFormat", { _this select 0 }];
    if (isNil "BIS_fnc_typeText") exitWith {
        hint parseText format [
            "<t align='center' size='1.4' font='PuristaBold' color='#FFD700'>%1</t><br/><br/><t align='center' size='0.95' color='#D0D0D0'>%2</t>%3<br/><br/><t color='#E0E0E0'>Read your <t color='#FFCC00'>Task</t> panel for the full SMEAC.</t>",
            _operationName,
            _missionTypeLabel,
            if (_loreShort isEqualType "" && { _loreShort != "" }) then {
                format ["<br/><br/><t align='center' size='0.82' color='#A8C4E0'>%1</t>", [_loreShort] call _escapeFmt]
            } else { "" }
        ];
    };
    private _holdSec = 4;
    [_lines, _taskHint, _operationName, _missionTypeLabel, _holdSec, _loreShort, _escapeFmt] spawn {
        params ["_lines", "_taskHint", "_operationName", "_missionTypeLabel", "_holdSec", "_loreShort", "_escapeFmt"];
        private _h = [_lines] spawn BIS_fnc_typeText;
        waitUntil { sleep 0.05; scriptDone _h };
        private _loreHtml = if (_loreShort isEqualType "" && { _loreShort != "" }) then {
            format ["<br/><t align='center' shadow='1' size='0.82' color='#A8C4E0'>%1</t>", [_loreShort] call _escapeFmt]
        } else { "" };
        private _holdParsed = parseText format [
            "<t align='center' shadow='1' size='1.15' font='PuristaBold' color='#FFD700'>%1</t><br/><t align='center' shadow='1' size='0.9' color='#D0D0D0'>%2</t>%3",
            _operationName,
            _missionTypeLabel,
            _loreHtml
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
FADE_applyScenarioClientSync = {
    params ["_pack"];
    if (!(_pack isEqualType []) || { count _pack < 8 }) exitWith {};
    if ((_pack select 0) isEqualTo "v1") exitWith {
        _pack params [
            "_ver",
            "_friendlyFaction",
            "_limitGear",
            "_presetOnly",
            "_enemyFaction",
            "_civFaction",
            "_civTalkInterpretersOnly",
            "_intelSpecialistsOnly",
            "_friendlyUnits",
            "_enemyUnits",
            "_friendlyVehicleClasses",
            "_limitPresets",
            "_teleportMode",
            "_sideEnemy",
            "_sideFriendly",
            "_enemySideNum",
            "_friendlySideNum",
            "_markerEnemy",
            "_markerFriendly"
        ];
        missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
        missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
        missionNamespace setVariable ["FADE_limitToPresetLoadouts", _presetOnly];
        missionNamespace setVariable ["FADE_scenarioEnemyFaction", _enemyFaction];
        missionNamespace setVariable ["FADE_scenarioCivFaction", _civFaction];
        missionNamespace setVariable ["FADE_civTalkInterpretersOnly", _civTalkInterpretersOnly];
        missionNamespace setVariable ["FADE_intelSpecialistsOnly", _intelSpecialistsOnly];
        missionNamespace setVariable ["FADE_friendlyUnits", _friendlyUnits];
        missionNamespace setVariable ["FADE_enemyUnits", _enemyUnits];
        missionNamespace setVariable ["FADE_friendlyVehicleClasses", _friendlyVehicleClasses];
        missionNamespace setVariable ["FADE_teleportToPlayerMode", _teleportMode];
        missionNamespace setVariable ["FADE_sideEnemy", _sideEnemy];
        missionNamespace setVariable ["FADE_sideFriendly", _sideFriendly];
        missionNamespace setVariable ["FADE_scenarioEnemySideNum", _enemySideNum];
        missionNamespace setVariable ["FADE_scenarioFriendlySideNum", _friendlySideNum];
        missionNamespace setVariable ["FADE_markerColorEnemy", _markerEnemy];
        missionNamespace setVariable ["FADE_markerColorFriendly", _markerFriendly];
    };
};

// Mission slot sync (packed PV from server).
"FADE_missionSlotsSync" addPublicVariableEventHandler {
    params ["_varName", "_val"];
    if (_val isEqualType []) then { [_val] call FADE_applyMissionSlotsClientSync };
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
call compile preprocessFileLineNumbers "rsc\FAC_Theme.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf";
call compile preprocessFileLineNumbers "rsc\FADE_MapClickPick.sqf";
call compile preprocessFileLineNumbers "rsc\GeoGuesserClient.sqf";
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
        if (!isNull (findDisplay 60700)) then { call FAC_ensureFiresGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_firesGui_fnc") };
        if (!isNull (findDisplay 60800)) then { call FAC_ensureMedicalTrainingGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_medicalTrainingGui_fnc") };
        if (!isNull (findDisplay 60910)) then { call FAC_ensureSniperGui; ["headerRefresh", []] call (missionNamespace getVariable "FAC_sniperGui_fnc") };
    };
};
missionNamespace setVariable ["FAC_guiScheduleHeaderRefresh", FAC_guiScheduleHeaderRefresh];

// Client: FIRES timed drill hints (remoteExec from server; define before waitUntil).
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
FADE_fires_drill_clientCompleteHint = {
    params [["_html", ""]];
    if (!hasInterface) exitWith {};
    hint parseText _html;
};

private _iplT0 = if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { diag_tickTime } else { -1 };
waitUntil {
    sleep (if (missionNamespace getVariable ["FADE_profileMissionLoad", false]) then { 0.05 } else { 0.1 });
    missionNamespace getVariable ["FADE_clientInitReady", false]
};
if (_iplT0 >= 0) then {
    diag_log format ["[FAC profile] client waitUntil FADE_clientInitReady: %1 s", diag_tickTime - _iplT0];
};

private _initPack = missionNamespace getVariable ["FADE_scenarioClientSync", []];
if (count _initPack > 0) then { [_initPack] call FADE_applyScenarioClientSync };
"FADE_scenarioClientSync" addPublicVariableEventHandler {
    params ["_varName", "_val"];
    if (_val isEqualType []) then { [_val] call FADE_applyScenarioClientSync };
};
private _initSlots = missionNamespace getVariable ["FADE_missionSlotsSync", []];
if (count _initSlots > 0) then { [_initSlots] call FADE_applyMissionSlotsClientSync };

// Server remoteExec hooks (CQB loudspeaker, cutscene RTT) — keep loaded once past mission sync; not full GUI stack.
call compile preprocessFileLineNumbers "rsc\CqbLoudspeaker.sqf";
call compile preprocessFileLineNumbers "rsc\CutsceneClient.sqf";
call compile preprocessFileLineNumbers "rsc\FAC_ClientBoardActions.sqf";
[] call FAC_clientInstallBoardActions;

// Dev: scroll-wheel entry for test suites (lobby param debug tools / Zeus).
FAC_installDevScrollActions = {
    if (!hasInterface) exitWith {};
    {
        player removeAction _x;
    } forEach (missionNamespace getVariable ["FAC_devScrollActionIds", []]);
    missionNamespace setVariable ["FAC_devScrollActionIds", []];
    if !(["FAC_playerCanUseDebugTools"] call FAC_lobbyParams_callAccess) exitWith {
        diag_log "[FAC] Dev scroll-wheel actions skipped (need Zeus slot or Admin debug-tools lobby param).";
    };
    [] call FAC_playthroughSuite__loadSuite;
    if (isNil "FAC_playthroughSuite_runServer") then {
        systemChat "[FAC Playthrough] Scripts failed to load — check RPT for compile errors.";
        diag_log "[FAC] Dev playthrough suite failed to compile (see RPT).";
    };
    private _ids = [];
    _ids pushBack (player addAction [
        "<t color='#FFD700'>[DEV] Run FAC Test Suite</t>",
        { [] call FAC_missionTestSuite_execAll },
        [],
        0,
        false,
        true,
        "",
        "",
        5
    ]);
    _ids pushBack (player addAction [
        "<t color='#FFA45B'>[DEV] Run Mission Playthrough Suite</t>",
        { [] call FAC_playthroughSuite_execAll },
        [],
        0,
        false,
        true,
        "",
        "",
        5
    ]);
    missionNamespace setVariable ["FAC_devScrollActionIds", _ids];
};

[] spawn {
    sleep 2;
    [] call FAC_installDevScrollActions;
};
player addEventHandler ["Respawn", {
    params ["_unit"];
    if (_unit != player) exitWith {};
    [_unit] spawn {
        params ["_u"];
        sleep 1;
        if (_u == player) then { [] call FAC_installDevScrollActions };
    };
}];

// JIP / late connect: one initial scan + EntityCreated for ambient civ / base NPC talk actions.
[] spawn {
    if (!hasInterface) exitWith {};
    call FAC_ensureCivTalkGui;
    private _fn = missionNamespace getVariable ["FADE_civTalk_addLocalAction", {}];
    if (_fn isEqualType {}) then {
        {
            if (alive _x && {
                _x getVariable ["FADE_ambientCiv", false] || { _x getVariable ["FADE_baseNpcTalk", false] }
            }) then { [_x] call _fn };
        } forEach allUnits;
        addMissionEventHandler ["EntityCreated", {
            params ["_ent"];
            if (!(_ent isKindOf "Man")) exitWith {};
            [_ent] spawn {
                params ["_ent"];
                sleep 0.25;
                if (isNull _ent || {!alive _ent}) exitWith {};
                if !(_ent getVariable ["FADE_ambientCiv", false] || { _ent getVariable ["FADE_baseNpcTalk", false] }) exitWith {};
                private _talkFn = missionNamespace getVariable ["FADE_civTalk_addLocalAction", {}];
                if (_talkFn isEqualType {}) then { [_ent] call _talkFn };
            };
        }];
    };
    private _refresh = missionNamespace getVariable ["FADE_civTalk_refreshBaseNpcAction", {}];
    if (_refresh isEqualType {}) then { [] call _refresh };
    if (!isNil "FADE_baseNpc_clientEnsureInteract") then { [] call FADE_baseNpc_clientEnsureInteract };
};

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


// Mission test suite — manual only.
//   Full stack:  [] call FAC_missionTestSuite_execAll
//   Client only: [] call FAC_missionTestSuite_execClient
//   Server only: [player] remoteExec ["FAC_missionTestSuite_execServer", 2]
FAC_missionTestSuite_execClient = {
    if (!hasInterface) exitWith {};
    if (isNil "FAC_missionTestSuite_runClient") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    private _res = call FAC_missionTestSuite_runClient;
    if (!(isNil "_res") && { count _res >= 2 }) then {
        _res params ["_p", "_f"];
        systemChat format ["[FAC TestSuite] Client finished: %1 pass, %2 fail — see RPT for [FAC TestSuite].", _p, _f];
        [_res, [0, 0], false] call FAC_missionTestSuite_showSummary;
    } else {
        systemChat "[FAC TestSuite] Client: aborted (script error — check RPT).";
    };
};

FAC_missionTestSuite_execAll = {
    if (!hasInterface) exitWith {};
    if (isNil "FAC_missionTestSuite_runClient") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    if (isNil "FAC_missionTestSuite_runClient" || { isNil "FAC_missionTestSuite_showSummary" }) exitWith {
        systemChat "[FAC TestSuite] aborted: rsc\MissionTestSuite.sqf failed to load (check RPT).";
    };
    private _cRes = call FAC_missionTestSuite_runClient;
    missionNamespace setVariable ["FAC_missionTestSuite_clientRes", _cRes, false];
    if (isServer) then {
        private _sRes = [player] call FAC_missionTestSuite_runServer;
        [_cRes, _sRes, false] call FAC_missionTestSuite_showSummary;
    } else {
        [_cRes, [0, 0], true] call FAC_missionTestSuite_showSummary;
        [player, true] remoteExec ["FAC_missionTestSuite_execServer", 2];
    };
};

FAC_missionTestSuite_onServerDone = {
    params ["_serverRes"];
    if (!hasInterface) exitWith {};
    if (isNil "FAC_missionTestSuite_showSummary") then {
        call compile preprocessFileLineNumbers "rsc\MissionTestSuite.sqf";
    };
    if (isNil "FAC_missionTestSuite_showSummary") exitWith {};
    private _cRes = missionNamespace getVariable ["FAC_missionTestSuite_clientRes", [0, 0]];
    [_cRes, _serverRes, false] call FAC_missionTestSuite_showSummary;
};

// Mission playthrough suite — sequential live mission tests (server authority).
//   [] call FAC_playthroughSuite_execAll
//   Abort in progress: [] call FAC_playthroughSuite_abort
FAC_playthroughSuite__loadSuite = {
    if (isNil "FAC_playthroughSuite_runServer") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughSuite.sqf";
    };
    if (isNil "FAC_playthroughSuite__runComplete") then {
        call compile preprocessFileLineNumbers "rsc\MissionPlaythroughProfiles.sqf";
    };
};

FAC_playthroughSuite_abort = {
    if (isServer) then {
        if (isNil "FAC_playthroughSuite__setAbortRequested") then {
            [] call FAC_playthroughSuite__loadSuite;
        };
        [] call FAC_playthroughSuite__setAbortRequested;
    } else {
        [] remoteExec ["FAC_playthroughSuite_abortServer", 2];
        systemChat "[FAC Playthrough] Abort requested.";
    };
};

FAC_playthroughSuite_execAll = {
    if (!hasInterface) exitWith {};
    [] call FAC_playthroughSuite__loadSuite;
    if (isNil "FAC_playthroughSuite_runServer") exitWith {
        systemChat "[FAC Playthrough] aborted: rsc\MissionPlaythroughSuite.sqf failed to load (check RPT).";
    };
    systemChat "[FAC Playthrough] Starting sequential playthrough (<=10 min, no input — see RPT).";
    if (isServer) then {
        [player] call FAC_playthroughSuite_runServer;
    } else {
        [player] remoteExec ["FAC_playthroughSuite_execServer", 2];
    };
};