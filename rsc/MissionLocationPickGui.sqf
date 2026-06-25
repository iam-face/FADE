// =============================================================================
// MissionLocationPickGui.sqf  -  Random vs map-click overlay on Manage Missions (60002)
// =============================================================================
if (hasInterface) then {
    FAC_missionLocationPickGui_fnc_missionDisplayName = {
        params ["_typeId"];
        private _dn = _typeId;
        private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
        { if ((_x select 1) == _typeId) exitWith { _dn = _x select 0 } } forEach _list;
        _dn
    };

    FAC_missionLocationPickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                _params params [["_missionType", ""]];
                if (_missionType == "") exitWith { systemChat "MISSION: no mission type selected."; };
                if (isNull _display) exitWith {
                    systemChat "MISSION: open Manage Missions first, then start a mission.";
                };
                disableSerialization;
                ["FAC_mlocPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
                [false] call FAC_missionPickOverlay_setBaseVisible;
                uinamespace setVariable ["FAC_missionLocPick_type", _missionType];
                private _titleName = [_missionType] call FAC_missionLocationPickGui_fnc_missionDisplayName;
                private _helpText = if (_missionType == "TroopInsert") then {
                    format [
                        "Random: first insert LZ is chosen automatically.%1Map click: choose the first LZ only (%2 s limit). Recurring mode still uses random link-up and LZ positions within mission distance rules after the first drop.",
                        toString [10, 10],
                        missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                    ]
                } else {
                    if (_missionType in (missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []])) then {
                        format [
                            "Random: mission area is chosen automatically.%1Map click: snaps to the nearest civ settlement zone to your click, then places the mission there (%2 s limit).",
                            toString [10, 10],
                            missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                        ]
                    } else {
                        format [
                            "Random: mission area is chosen automatically.%1Map click: choose a point on the map (%2 s limit). The server searches 250 m, then 500 m, 1 km, 2.5 km, 5 km, then the whole map for a valid site as close as possible to your click.",
                            toString [10, 10],
                            missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                        ]
                    }
                };
                private _controls = [_display, format ["%1 - CHOOSE LOCATION", toUpper _titleName], _helpText, 60340, [0.12, 0.58, 0.048, 0.14]] call FAC_missionPickOverlay_createShell;
                private _btnY = 0.36;
                private _bRandom = _display ctrlCreate ["RscButton", 60343];
                _bRandom ctrlSetPosition [0.06, _btnY, 0.88, 0.065];
                _bRandom ctrlSetText "Random location";
                _bRandom ctrlSetBackgroundColor [0.18, 0.32, 0.48, 1];
                _bRandom ctrlCommit 0;
                _bRandom ctrlAddEventHandler ["ButtonClick", { ["random", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bRandom;
                private _bMap = _display ctrlCreate ["RscButton", 60344];
                _bMap ctrlSetPosition [0.06, _btnY + 0.08, 0.88, 0.065];
                _bMap ctrlSetText "Map click (choose area on map)";
                _bMap ctrlSetBackgroundColor [0.18, 0.38, 0.32, 1];
                _bMap ctrlCommit 0;
                _bMap ctrlAddEventHandler ["ButtonClick", { ["mapClick", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bMap;
                private _bCancel = _display ctrlCreate ["RscButton", 60345];
                _bCancel ctrlSetPosition [0.06, _btnY + 0.16, 0.88, 0.055];
                _bCancel ctrlSetText "Cancel";
                _bCancel ctrlCommit 0;
                _bCancel ctrlAddEventHandler ["ButtonClick", { ["cancel", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bCancel;
                uinamespace setVariable ["FAC_mlocPick_overlayCtrls", _controls];
            };
            case "random": {
                private _mt = uinamespace getVariable ["FAC_missionLocPick_type", ""];
                if (_mt == "") exitWith {};
                ["FAC_mlocPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
                if (_mt == "TroopInsert") then {
                    uinamespace setVariable ["FAC_troopInsert_lzAnchor", []];
                    if (isNil "FAC_troopInsertPickGui_fnc") exitWith { systemChat "TROOP INSERT UI not loaded."; };
                    ["open", []] call FAC_troopInsertPickGui_fnc;
                } else {
                    [_mt, player, []] remoteExec ["FADE_startMission", 2];
                    hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
                    [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
                };
            };
            case "mapClick": {
                private _mt = uinamespace getVariable ["FAC_missionLocPick_type", ""];
                if (_mt == "") exitWith {};
                ["FAC_mlocPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
                private _missionsDisp = findDisplay 60002;
                if (_mt != "TroopInsert" && { !isNull _missionsDisp }) then { closeDialog 60002 };
                missionNamespace setVariable ["FAC_missionMapPick_execType", _mt];
                [] spawn {
                    sleep 0.15;
                    execVM "rsc\MissionMapPick_exec.sqf";
                };
            };
            case "cancel": {
                ["FAC_mlocPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_missionLocationPickGui_fnc", FAC_missionLocationPickGui_fnc];
};
