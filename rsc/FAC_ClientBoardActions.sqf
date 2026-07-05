// =============================================================================
// FAC_ClientBoardActions.sqf � terminal/board addAction setup (initPlayerLocal)
// =============================================================================

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

// KeyDown on main display (46): Ctrl+; = Missions GUI; Ctrl+Shift+apostrophe = Fast Travel.
// Install this before board/action setup so unrelated addAction or lazy-GUI errors cannot break hotkeys.
FAC_clientInstallHotkeys = {
    if (!hasInterface) exitWith {};
    if (missionNamespace getVariable ["FAC_clientHotkeysInstallQueued", false]) exitWith {};
    missionNamespace setVariable ["FAC_clientHotkeysInstallQueued", true];

    [] spawn {
        waitUntil { sleep 0.05; !isNull (findDisplay 46) };
        if (missionNamespace getVariable ["FAC_clientHotkeysInstalled", false]) exitWith {};

        private _ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["_display", "_key", "_shift", "_ctrl", "_alt"];
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
            if (_key == 0x28 && { _shift } && { _ctrl }) exitWith {
                if (isNull (findDisplay 60600)) then {
                    call FAC_ensureTeleportGui;
                    ["open", []] call FAC_teleportGui_fnc;
                };
                true
            };
            false
        }];
        missionNamespace setVariable ["FAC_clientHotkeysEhId", _ehId];
        missionNamespace setVariable ["FAC_clientHotkeysInstalled", true];
    };
};

FAC_clientInstallBoardActions = {
    if (!hasInterface) exitWith {};
    call FAC_clientInstallHotkeys;

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
// objWorkbench: Save loadout + attachments-only ACE Arsenal (no Manage My Loadout).
[] spawn {
    sleep 0.5;
    call FAC_ensureLoadoutGui;
    private _boxes = missionNamespace getVariable ["FADE_loadoutBoxes", []];
    if (_boxes isEqualTo [] && { !isNull (missionNamespace getVariable ["FADE_loadoutBox", objNull]) }) then {
        _boxes = [missionNamespace getVariable "FADE_loadoutBox"];
        if (!isNull (missionNamespace getVariable ["FADE_loadoutBox2", objNull])) then { _boxes pushBack (missionNamespace getVariable "FADE_loadoutBox2") };
    };
    private _workbench = missionNamespace getVariable ["FADE_workbench", missionNamespace getVariable [missionNamespace getVariable ["FADE_workbenchEdenName", "objWorkbench"], objNull]];
    {
        private _box = _x;
        if (isNull _box) then { continue };
        private _isWorkbench = !isNull _workbench && { _box isEqualTo _workbench };
        removeAllActions _box;
        if (!_isWorkbench) then {
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
        };
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
                    if (_isWorkbench) then { "<t color='#FF8C00'>Use Crusty's Workbench</t>" } else { "<t color='#FF8C00'>Open ACE Arsenal</t>" },
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

// HQ recruit board (Eden: hqRecruitBoard)
[] spawn {
    sleep 0.55;
    private _board = missionNamespace getVariable ["FADE_hqRecruitBoard", objNull];
    if (isNull _board) then { _board = missionNamespace getVariable ["hqRecruitBoard", objNull] };
    if (isNull _board) exitWith {};
    removeAllActions _board;
    _board addAction [
        "<t color='#7CFC00'>Recruit units</t>",
        {
            if !(["FAC_playerCanUseRecruitGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Recruit GUI access denied by lobby settings.";
            };
            [] spawn { call FAC_ensureRecruitGui; sleep 0.2; ["open", []] call FAC_recruitGui_fnc };
        },
        [],
        6,
        false,
        true,
        "",
        "",
        3
    ];
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

// Jukebox: Vehicle loudspeaker UI on the *player unit* only (local addAction / ACE self  -  not on vehicle hull)
call FAC_ensureJukeboxGui;
if (!isNil "FAC_jukebox_fnc_addVehicleLoudspeakerAction") then {
    [player] call FAC_jukebox_fnc_addVehicleLoudspeakerAction;
};
if (!isNil "FAC_jukebox_fnc_installVehicleLoudspeakerHandlers") then {
    [player] call FAC_jukebox_fnc_installVehicleLoudspeakerHandlers;
};

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

// Locker Room -- hostage VO + locker slaps (posLockerRoom + posLockers_1/2); see rsc\Config.sqf
[] execVM "rsc\LockerRoomAmbient.sqf";

};

missionNamespace setVariable ["FAC_addScenarioActionToTerminal", FAC_addScenarioActionToTerminal];
missionNamespace setVariable ["FAC_clientInstallHotkeys", FAC_clientInstallHotkeys];
missionNamespace setVariable ["FAC_clientInstallBoardActions", FAC_clientInstallBoardActions];