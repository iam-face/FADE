// =============================================================================
// MissionsGui.sqf - Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).

// [displayName, missionId, description, "Global"|"Single"] - stream is for logic; list shows [G]/[S]
private _missionListRaw = [
    ["Area of Operations", "AreaOfOperations", "2 km x 2 km AO. BLUFOR assault; capture 3 objectives. OPFOR defend. [G]", "Global"],
    ["CAS / Fire Support", "CAS", "Engage enemy forces and support friendlies at the objective. [G]", "Global"],
    ["Cargo / Resupply", "Cargo", "Cargo box at CargoPoint_1. Fly to camp and land to complete. [S]", "Single"],
    ["Clear Area", "ClearArea", "Enemy-occupied town or camp. Destroy at least 80% of enemy. [G]", "Global"],
    ["Find and Clear IEDs", "FindClearIEDs", "Locate and disarm an IED on a road near a civ zone. [S]", "Single"],
    ["Hostage", "Hostage", "Rescue hostages from urban buildings. Return all alive to base. [G]", "Global"],
    ["HVT", "HVT", "High value target in urban building. Eliminate or capture. [G]", "Global"],
    ["Intercept Convoy", "InterceptConvoy", "Destroy convoy before it reaches the end zone. [G]", "Global"],
    ["Mass Casualty (MASCAS)", "MASCAS", "3–6 BLUFOR with injuries at MEDICAL_1. Heal all. [S], ACE", "Single"],
    ["Mass Casualty (MASCAS) KAT", "MASCASKAT", "3–6 BLUFOR with injuries at MEDICAL_1. Heal all. [S], KAT", "Single"],
    ["Medical", "Medical", "One BLUFOR with injury, heal to complete. [S], ACE", "Single"],
    ["Medical KAT", "MedicalKAT", "One BLUFOR with injury, heal to complete. [S], KAT", "Single"],
    ["Mine Clearing", "MineClearing", "Clear 5–10 mines in a 200 m area. Complete when all disarmed. [S]", "Single"],
    ["Troop Extract", "TroopExtract", "Fly to pickup zone, land to load squad, return to base. [S]", "Single"],
    ["Troop Insert", "TroopInsert", "Pick up squad at base, fly to LZ, land to disembark. [S]", "Single"]
];
private _sorted = [_missionListRaw, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
if (isNil "_sorted" || { !(_sorted isEqualType []) }) then { _sorted = _missionListRaw };
missionNamespace setVariable ["FAC_missionsGui_missionList", _sorted];

// Default intro when no mission selected
FAC_missionsGui_defaultDesc = "Select a mission from the list to view details. After you start one, this area shows pickup, objectives, and completion criteria from your task briefing.";

FADE_receiveCopilotState = {
    params [["_hasCopilot", false]];
    missionNamespace setVariable ["FAC_missions_hasCopilot", _hasCopilot];
    if (!isNull (findDisplay 60002)) then { ["updateButtons", []] call FAC_missionsGui_fnc };
};

FAC_missionsGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60002;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayMissions") then {
                systemChat "MISSIONS GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60002;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_missionsGui_fnc", FAC_missionsGui_fnc];
            missionNamespace setVariable ["FAC_missions_abortPendingTime", -99];

            // Mission list: displayName + [G] or [S]
            private _mLb = _display displayCtrl 60120;
            lbClear _mLb;
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            {
                _x params [["_name", ""], ["_id", ""], ["_desc", ""], ["_stream", "Single"]];
                private _tag = if (_stream == "Global") then {" [G]"} else {" [S]"};
                private _idx = _mLb lbAdd (_name + _tag);
                _mLb lbSetData [_idx, _id];
            } forEach _missionList;
            _mLb lbSetCurSel -1;

            ["missionSelChanged", []] call FAC_missionsGui_fnc;
            private _rulesCtrl = _display displayCtrl 60133;
            if (!isNull _rulesCtrl) then {
                private _nl = toString [10];
                _rulesCtrl ctrlSetText (
                    "Global missions [G] are large, shared scenarios for the whole mission. Only one may run at a time." + _nl +
                    "Single missions [S] are smaller tasks in separate areas. Up to three may run at once, each started by a different player." + _nl +
                    "You can only start one mission at a time yourself, [G] or [S] - type does not matter. Abort or finish before starting another."
                );
                _rulesCtrl ctrlEnable false;
            };
            ["refreshStatus", []] call FAC_missionsGui_fnc;
            [] spawn { sleep 0.05; if (!isNull (findDisplay 60002)) then { ["refreshDescription", []] call FAC_missionsGui_fnc } };
            ["updateButtons", []] call FAC_missionsGui_fnc;
            missionNamespace setVariable ["FAC_missions_hasCopilot", false];
            [player] remoteExec ["FADE_requestCopilotState", 2];
            // Delayed refresh so abort button picks up replicated mission vars (e.g. after starting Clear Area and reopening GUI)
            [] spawn { sleep 0.25; if (!isNull (findDisplay 60002)) then { ["refreshStatus", []] call FAC_missionsGui_fnc } };
        };
        case "spawnCopilot": {
            [player] remoteExec ["FADE_spawnCopilot", 2];
            [] spawn {
                sleep 0.6;
                [player] remoteExec ["FADE_requestCopilotState", 2];
            };
        };
        case "removeCopilot": {
            [player] remoteExec ["FADE_removeCopilot", 2];
            [] spawn {
                sleep 0.4;
                [player] remoteExec ["FADE_requestCopilotState", 2];
            };
        };
        case "abortMission": {
            if (isNull _display) exitWith {};
            private _btn = _display displayCtrl 60122;
            private _pendingTime = missionNamespace getVariable ["FAC_missions_abortPendingTime", -99];
            if (time - _pendingTime > 3) then {
                missionNamespace setVariable ["FAC_missions_abortPendingTime", time];
                _btn ctrlSetText "CONFIRM ABORT?";
                _btn ctrlSetTextColor [1, 0.35, 0.35, 1];
                [] spawn {
                    sleep 3;
                    missionNamespace setVariable ["FAC_missions_abortPendingTime", -99];
                    if (!isNull (findDisplay 60002)) then {
                        private _b = (findDisplay 60002) displayCtrl 60122;
                        _b ctrlSetText "ABORT MISSION";
                        _b ctrlSetTextColor [1, 1, 1, 1];
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_missions_abortPendingTime", -99];
                _btn ctrlSetText "ABORT MISSION";
                _btn ctrlSetTextColor [1, 1, 1, 1];
                [player] remoteExec ["FADE_abortMission", 2];
                hint parseText "<t size='1.1' color='#B0B0B0'>Aborting mission...</t>";
                [] spawn { sleep 1; if (!isNull (findDisplay 60002)) then { ["refreshStatus", []] call FAC_missionsGui_fnc } };
            };
        };
        case "startMission": {
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 60120;
            private _idx = lbCurSel _lb;
            if (_idx < 0) then { systemChat "SELECT MISSION."; return };
            private _missionType = _lb lbData _idx;
            [_missionType, player] remoteExec ["FADE_startMission", 2];
            hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
            [] spawn { sleep 1; if (!isNull (findDisplay 60002)) then { ["refreshStatus", []] call FAC_missionsGui_fnc } };
        };
        case "refreshStatus": {
            if (isNull _display) exitWith {};
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _displayName = {
                params ["_typeId"];
                private _dn = _typeId;
                { if ((_x select 1) == _typeId) exitWith { _dn = _x select 0 } } forEach _missionList;
                _dn
            };
            private _ownerStr = {
                params ["_o"];
                if (!isNull _o) then { name _o } else { "?" }
            };
            private _nl = toString [10];
            private _slotGlobal = _display displayCtrl 60130;
            if (!isNull _slotGlobal) then {
                if (count _global >= 2) then {
                    private _type = _global select 0;
                    private _owner = _global select 1;
                    private _n = [_type] call _displayName;
                    private _oStr = [_owner] call _ownerStr;
                    _slotGlobal ctrlSetText (_n + _nl + "Started by: " + _oStr);
                } else {
                    _slotGlobal ctrlSetText ("No mission active." + _nl + "(Global slot is free.)");
                };
                _slotGlobal ctrlEnable false;
            };
            private _singleIdcs = [60134, 60135, 60136];
            {
                private _c = _display displayCtrl _x;
                private _entry = _singleList param [_forEachIndex, []];
                if (!isNull _c) then {
                    if (count _entry >= 2) then {
                        _entry params ["_t", "_o"];
                        private _n = [_t] call _displayName;
                        private _oStr = [_o] call _ownerStr;
                        _c ctrlSetText (_n + _nl + "Started by: " + _oStr);
                    } else {
                        _c ctrlSetText ("No mission in this slot.");
                    };
                    _c ctrlEnable false;
                };
            } forEach _singleIdcs;
            ["refreshDescription", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _missionLb = _display displayCtrl 60120;
            private _startBtn = _display displayCtrl 60121;
            private _abortBtn = _display displayCtrl 60122;
            private _copilotSpawnBtn = _display displayCtrl 60141;
            private _copilotRemoveBtn = _display displayCtrl 60142;
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _uid = getPlayerUID player;
            private _playerHasMission = (
                count _global >= 2 && {
                    (_global select 1 == player) || { (_global param [3, ""]) == _uid }
                }
            ) || {
                {
                    ((_x param [1, objNull]) == player) || { (_x param [3, ""]) == _uid }
                } count _singleList > 0
            };
            private _idx = lbCurSel _missionLb;
            private _canStart = lbSize _missionLb > 0 && { _idx >= 0 } && { !_playerHasMission };
            if (_canStart && { _idx >= 0 }) then {
                private _missionId = _missionLb lbData _idx;
                private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
                private _stream = "Single";
                { if ((_x select 1) == _missionId) exitWith { _stream = _x select 3 } } forEach _list;
                if (_stream == "Global" && { count _global >= 1 }) then { _canStart = false };
                if (_stream == "Single" && { count _singleList >= 3 }) then { _canStart = false };
            };
            _startBtn ctrlEnable _canStart;
            _abortBtn ctrlEnable _playerHasMission;
            private _hasCopilot = missionNamespace getVariable ["FAC_missions_hasCopilot", false];
            if (!isNull _copilotSpawnBtn) then { _copilotSpawnBtn ctrlEnable (!_hasCopilot) };
            if (!isNull _copilotRemoveBtn) then { _copilotRemoveBtn ctrlEnable _hasCopilot };
        };
        case "missionSelChanged": {
            ["refreshDescription", []] call FAC_missionsGui_fnc;
        };
        // Description: shows *your* FADE_myMissionBrief while you have an active mission; otherwise the
        // static blurb for the currently selected list row. It does not merge or rotate multiple active missions.
        case "refreshDescription": {
            if (isNull _display) exitWith {};
            private _descCtrl = _display displayCtrl 60131;
            if (isNull _descCtrl) exitWith {};
            private _brief = player getVariable ["FADE_myMissionBrief", ""];
            private _text = "";
            if (_brief isEqualType "" && { count _brief > 0 }) then {
                _text = _brief;
            } else {
                private _mLb = _display displayCtrl 60120;
                private _idx = lbCurSel _mLb;
                _text = FAC_missionsGui_defaultDesc;
                if (_idx >= 0) then {
                    private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
                    if (_idx < count _list) then {
                        private _mission = _list select _idx;
                        _text = _mission param [2, _text];
                    };
                };
            };
            if (count _text > 0) then {
                _descCtrl ctrlSetText _text;
            } else {
                _descCtrl ctrlSetText FAC_missionsGui_defaultDesc;
            };
        };
    };
};
