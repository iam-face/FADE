// =============================================================================
// MissionsGui.sqf — Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).

// [displayName, missionId, description, "Global"|"Single"] — store in missionNamespace only (no global) so dialog always has a list
private _missionListRaw = [
    ["Area of Operations", "AreaOfOperations", "2 km x 2 km AO. BLUFOR assault; capture 3 objectives. OPFOR defend. (Global)", "Global"],
    ["CAS / Fire Support", "CAS", "Engage enemy forces and support friendlies at the objective. (Global)", "Global"],
    ["Cargo / Resupply", "Cargo", "Cargo box at CargoPoint_1. Fly to camp and land to complete. (Single)", "Single"],
    ["Clear Area", "ClearArea", "Enemy-occupied town or camp. Destroy at least 80% of enemy. (Global)", "Global"],
    ["Find and Clear IEDs", "FindClearIEDs", "Locate and disarm an IED on a road near a civ zone. (Single)", "Single"],
    ["Hostage", "Hostage", "Rescue hostages from urban buildings. Return all alive to base. (Global)", "Global"],
    ["HVT", "HVT", "High value target in urban building. Eliminate or capture. (Global)", "Global"],
    ["Intercept Convoy", "InterceptConvoy", "Destroy convoy before it reaches the end zone. (Global)", "Global"],
    ["Mass Casualty (MASCAS)", "MASCAS", "3–6 BLUFOR with injuries at MEDICAL_1. Heal all. (Single, ACE)", "Single"],
    ["Mass Casualty (MASCAS) KAT", "MASCASKAT", "3–6 BLUFOR with injuries at MEDICAL_1. Heal all. (Single, KAT)", "Single"],
    ["Medical", "Medical", "One BLUFOR with injury, heal to complete. (Single, ACE)", "Single"],
    ["Medical KAT", "MedicalKAT", "One BLUFOR with injury, heal to complete. (Single, KAT)", "Single"],
    ["Mine Clearing", "MineClearing", "Clear 5–10 mines in a 200 m area. Complete when all disarmed. (Single)", "Single"],
    ["Troop Extract", "TroopExtract", "Fly to pickup zone, land to load squad, return to base. (Single)", "Single"],
    ["Troop Insert", "TroopInsert", "Pick up squad at base, fly to LZ, land to disembark. (Single)", "Single"]
];
private _sorted = [_missionListRaw, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
if (isNil "_sorted" || { !(_sorted isEqualType []) }) then { _sorted = _missionListRaw };
missionNamespace setVariable ["FAC_missionsGui_missionList", _sorted];

// Default intro when no mission selected
FAC_missionsGui_defaultDesc = "Select a mission from the list to view details. When you start a mission, this area will show pickup location, target area, objectives and completion criteria. Players can only spawn one mission themselves. 3 x Single missions are permitted at any time, 1 x Global mission is permitted at any time.";

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

            // Mission list: displayName (Global) or (Single)
            private _mLb = _display displayCtrl 60120;
            lbClear _mLb;
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            { _x params [["_name", ""], ["_id", ""], ["_desc", ""], ["_stream", "Single"]]; private _idx = _mLb lbAdd (_name + " (" + _stream + ")"); _mLb lbSetData [_idx, _id] } forEach _missionList;
            _mLb lbSetCurSel -1;

            ["missionSelChanged", []] call FAC_missionsGui_fnc;
            ["refreshStatus", []] call FAC_missionsGui_fnc;
            [] spawn { sleep 0.05; if (!isNull (findDisplay 60002)) then { ["refreshDescription", []] call FAC_missionsGui_fnc } };
            ["updateButtons", []] call FAC_missionsGui_fnc;
            // Delayed refresh so abort button picks up replicated mission vars (e.g. after starting Clear Area and reopening GUI)
            [] spawn { sleep 0.25; if (!isNull (findDisplay 60002)) then { ["refreshStatus", []] call FAC_missionsGui_fnc } };
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
            private _status = _display displayCtrl 60130;
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _globalStr = if (count _global >= 2) then {
                private _type = _global select 0;
                private _owner = _global select 1;
                private _typeName = _type;
                { if ((_x select 1) == _type) exitWith { _typeName = _x select 0 } } forEach _missionList;
                "Global: " + _typeName + " (" + (if (!isNull _owner) then { name _owner } else { "?" }) + ")"
            } else { "Global: None" };
            private _singleStr = if (_singleList isEqualTo []) then { "Single: None" } else {
                private _parts = _singleList apply {
                    _x params ["_t", "_o", "_p"];
                    private _dn = _t;
                    { if ((_x select 1) == _t) exitWith { _dn = _x select 0 } } forEach _missionList;
                    _dn + " (" + (if (!isNull _o) then { name _o } else { "?" }) + ")"
                };
                "Single: " + (_parts joinString ", ")
            };
            _status ctrlSetText (_globalStr + " | " + _singleStr);
            _status ctrlSetTextColor [0.85, 0.9, 0.85, 1];
            ["refreshDescription", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _missionLb = _display displayCtrl 60120;
            private _startBtn = _display displayCtrl 60121;
            private _abortBtn = _display displayCtrl 60122;
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _playerHasMission = (count _global >= 2 && { _global select 1 == player }) || { { _x select 1 == player } count _singleList > 0 };
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
        };
        case "missionSelChanged": {
            ["refreshDescription", []] call FAC_missionsGui_fnc;
        };
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
