// =============================================================================
// MissionLocationPickGui.sqf  -  Random vs map-click overlay on Manage Missions (60002)
// =============================================================================
if (hasInterface) then {
    FAC_missionLocationPickGui_fnc_destroyOverlay = {
        if (isNil "FAC_missionPickOverlay_destroy") exitWith {};
        ["FAC_mlocPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };

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
                if (_missionType in ["TroopInsert", "TroopExtract"]) exitWith {
                    if (isNil "FAC_troopInsertPickGui_fnc") exitWith { systemChat "TROOP TRANSPORT UI not loaded."; };
                    uinamespace setVariable ["FAC_troopTransport_mapAnchor", []];
                    uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                    ["open", [_missionType]] call FAC_troopInsertPickGui_fnc;
                };
                if (isNull _display) exitWith {
                    systemChat "MISSION: open Manage Missions first, then start a mission.";
                };
                if (isNil "FAC_missionPickOverlay_createShell") exitWith {
                    systemChat "MISSION: location overlay not loaded.";
                };
                disableSerialization;
                if (!isNil "FAC_missionPickOverlay_destroy") then {
                    [] call FAC_missionLocationPickGui_fnc_destroyOverlay;
                };
                if (!isNil "FAC_missionPickOverlay_setBaseVisible") then {
                    [false] call FAC_missionPickOverlay_setBaseVisible;
                };
                uinamespace setVariable ["FAC_missionLocPick_type", _missionType];
                private _titleName = [_missionType] call FAC_missionLocationPickGui_fnc_missionDisplayName;
                private _helpText = if (_missionType == "InterceptConvoy") then {
                    format [
                        "Random: convoy start and end chosen on roads (min route length applies).%1Map click: choose start, then end (%2 s per click). Each point snaps to the nearest road within 500 m (no min length).%1%1Enemy corridor dots show the expected route.",
                        toString [10, 10],
                        missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                    ]
                } else {
                    if (_missionType == "Raid") then {
                        private _rz = (round (missionNamespace getVariable ["FADE_raidObjectiveCount", 3])) max 2 min 5;
                        private _minD = missionNamespace getVariable ["FADE_minDistBetweenMissions", 2000];
                        format [
                            "Random: three objective zones from civ settlements.%1Map click: place %2 zones (%3 s per click; timer resets each zone). Keep zones at least %4 m apart. Map stays open until all are placed. Each click snaps to the nearest civ zone.",
                            toString [10, 10],
                            _rz,
                            missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20],
                            _minD
                        ]
                    } else {
                    if (_missionType in (missionNamespace getVariable ["FADE_missionMapClickSnapCivZoneTypes", []])) then {
                        format [
                            "Random: mission area chosen automatically.%1Map click: snaps to the nearest civ zone to your click (%2 s limit).",
                            toString [10, 10],
                            missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                        ]
                    } else {
                        format [
                            "Random: mission area chosen automatically.%1Map click: pick a point (%2 s). Server searches 250 m, then 500 m, 1 km, 2.5 km, 5 km, then the whole map for a valid site near your click.",
                            toString [10, 10],
                            missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20]
                        ]
                    }
                    }
                };
                private _padX = 0.04;
                private _bgW = 0.64;
                private _bgX = 0.18;
                private _titleH = 0.046;
                private _innerW = _bgW - (_padX * 2);
                private _helpH = 0.15;
                if (!isNil "FAC_missionPickOverlay_estimateHelpH") then {
                    _helpH = [_helpText, _innerW] call FAC_missionPickOverlay_estimateHelpH;
                };
                if (!(_helpH isEqualType 0)) then { _helpH = 0.15 };
                private _btnH = 0.052;
                private _btnGap = 0.012;
                private _btnBlock = (_btnH * 3) + (_btnGap * 2) + 0.028;
                private _bgH = _titleH + 0.012 + _helpH + _btnBlock + 0.016;
                private _bgY = ((1 - _bgH) / 2) max 0.08;
                private _layout = [_bgX, _bgY, _bgW, _bgH, _titleH, _helpH];
                private _controls = [_display, format ["%1 - CHOOSE LOCATION", toUpper _titleName], _helpText, 60340, _layout] call FAC_missionPickOverlay_createShell;
                private _innerX = _bgX + _padX;
                private _btnY = _bgY + _titleH + _helpH + 0.028;
                private _bRandom = _display ctrlCreate ["RscButton", 60343];
                _bRandom ctrlSetPosition [_innerX, _btnY, _innerW, _btnH];
                _bRandom ctrlSetText "Random location";
                [_bRandom] call FAC_missionPick_stylePrimary;
                _bRandom ctrlCommit 0;
                _bRandom ctrlAddEventHandler ["ButtonClick", { ["random", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bRandom;
                private _bMap = _display ctrlCreate ["RscButton", 60344];
                _bMap ctrlSetPosition [_innerX, _btnY + _btnH + _btnGap, _innerW, _btnH];
                _bMap ctrlSetText (
                    switch (_missionType) do {
                        case "InterceptConvoy": { "Map click (choose start and end)" };
                        case "Raid": { format ["Map click (choose %1 zones)", (round (missionNamespace getVariable ["FADE_raidObjectiveCount", 3])) max 2 min 5] };
                        default { "Map click (choose area on map)" };
                    }
                );
                [_bMap] call FAC_missionPick_styleStart;
                _bMap ctrlCommit 0;
                _bMap ctrlAddEventHandler ["ButtonClick", { ["mapClick", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bMap;
                private _bCancel = _display ctrlCreate ["RscButton", 60345];
                _bCancel ctrlSetPosition [_innerX, _btnY + (_btnH + _btnGap) * 2, _innerW, _btnH];
                _bCancel ctrlSetText "Cancel";
                [_bCancel] call FAC_missionPick_styleDanger;
                _bCancel ctrlCommit 0;
                _bCancel ctrlAddEventHandler ["ButtonClick", { ["cancel", []] call (missionNamespace getVariable ["FAC_missionLocationPickGui_fnc", {}]) }];
                _controls pushBack _bCancel;
                uinamespace setVariable ["FAC_mlocPick_overlayCtrls", _controls];
            };
            case "random": {
                private _mt = uinamespace getVariable ["FAC_missionLocPick_type", ""];
                if (_mt == "") exitWith {};
                [] call FAC_missionLocationPickGui_fnc_destroyOverlay;
                if (_mt in ["TroopInsert", "TroopExtract"]) then {
                    uinamespace setVariable ["FAC_troopTransport_mapAnchor", []];
                    uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                    if (isNil "FAC_troopInsertPickGui_fnc") exitWith { systemChat "TROOP TRANSPORT UI not loaded."; };
                    ["open", [_mt]] call FAC_troopInsertPickGui_fnc;
                } else {
                    [_mt, player, []] remoteExec ["FADE_startMission", 2];
                    hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Orders will show in Tasks when ready.</t>";
                    missionNamespace setVariable ["FAC_missionsGui_tab", "active"];
                    [] call FAC_missionsGui_syncTabs;
                    [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
                };
            };
            case "mapClick": {
                private _mt = uinamespace getVariable ["FAC_missionLocPick_type", ""];
                if (_mt == "") exitWith {};
                if (_mt in ["TroopInsert", "TroopExtract"]) exitWith {
                    systemChat "TROOP INSERT / EXTRACT: random location only - use START from Manage Missions.";
                };
                [] call FAC_missionLocationPickGui_fnc_destroyOverlay;
                private _missionsDisp = findDisplay 60002;
                if (_mt != "TroopInsert" && { _mt != "TroopExtract" } && { !isNull _missionsDisp }) then { closeDialog 60002 };
                if (_mt == "InterceptConvoy") exitWith {
                    [] spawn {
                        sleep 0.15;
                        execVM "rsc\MissionConvoyMapPick_exec.sqf";
                    };
                };
                if (_mt == "Raid") exitWith {
                    [] spawn {
                        sleep 0.15;
                        execVM "rsc\MissionRaidMapPick_exec.sqf";
                    };
                };
                missionNamespace setVariable ["FAC_missionMapPick_execType", _mt];
                [] spawn {
                    sleep 0.15;
                    execVM "rsc\MissionMapPick_exec.sqf";
                };
            };
            case "cancel": {
                [] call FAC_missionLocationPickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_missionLocationPickGui_fnc", FAC_missionLocationPickGui_fnc];
};
