// =============================================================================
// MissionsGui.sqf — Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).

// [displayName, missionId, description]
FAC_heliOpsGui_missionList = [
    ["Troop Insert", "TroopInsert", "Pick up squad at base, fly to LZ, land to disembark."],
    ["Troop Extract", "TroopExtract", "Fly to pickup zone, land to load squad, return to base and land."],
    ["CAS / Fire Support", "CAS", "Engage enemy forces and support friendlies at the objective."],
    ["Cargo / Resupply", "Cargo", "A cargo box spawns at CargoPoint_1; bringing it to camp is optional. Fly to camp and land to complete - no need to deliver the box."],
    ["HVT", "HVT", "High value target in an urban building. Eliminate or capture and return to base. Building guarded; patrols in area."],
    ["Hostage", "Hostage", "Rescue civilian hostages from urban building(s). Each hostage is guarded; patrols outside. Return all alive hostages to base (within 100 m). Mission fails if more than half the hostages die."],
    ["Clear Area", "ClearArea", "Enemy-occupied town or camp. Destroy at least 80% of enemy forces in the area."],
    ["Intercept Convoy", "InterceptConvoy", "Convoy moving between road points. Destroy all vehicles before they reach the end zone."]
];

// Default intro when no mission selected
FAC_heliOpsGui_defaultDesc = "Select a mission from the list to view details. When you start a mission, this area will show pickup location, target area, objectives and completion criteria.";

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

            // Mission list
            private _mLb = _display displayCtrl 60120;
            lbClear _mLb;
            { _x params ["_name", "_id"]; private _idx = _mLb lbAdd _name; _mLb lbSetData [_idx, _id] } forEach FAC_heliOpsGui_missionList;
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
                [player] remoteExec ["heliOps_abortMission", 2];
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
            [_missionType, player] remoteExec ["heliOps_startMission", 2];
            hint parseText "<t size='1.1' color='#A0D0A0'>Loading mission...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
            [] spawn { sleep 1; if (!isNull (findDisplay 60002)) then { ["refreshStatus", []] call FAC_missionsGui_fnc } };
        };
        case "refreshStatus": {
            if (isNull _display) exitWith {};
            private _status = _display displayCtrl 60130;
            private _active = player getVariable ["heliOps_myMission", ""];
            if (_active != "") then {
                private _name = _active;
                { if ((_x select 1) == _active) exitWith { _name = _x select 0 } } forEach FAC_heliOpsGui_missionList;
                _status ctrlSetText (format ["Mission active: %1", _name]);
                _status ctrlSetTextColor [1, 0.9, 0.5, 1];
            } else {
                _status ctrlSetText "No mission active";
                _status ctrlSetTextColor [0.7, 0.9, 0.7, 1];
            };
            ["refreshDescription", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _missionLb = _display displayCtrl 60120;
            private _startBtn = _display displayCtrl 60121;
            private _abortBtn = _display displayCtrl 60122;
            private _hasMission = (player getVariable ["heliOps_myMission", ""]) != "";
            _startBtn ctrlEnable (lbSize _missionLb > 0 && { lbCurSel _missionLb >= 0 } && { !_hasMission });
            _abortBtn ctrlEnable _hasMission;
        };
        case "missionSelChanged": {
            ["refreshDescription", []] call FAC_missionsGui_fnc;
        };
        case "refreshDescription": {
            if (isNull _display) exitWith {};
            private _descCtrl = _display displayCtrl 60131;
            if (isNull _descCtrl) exitWith {};
            private _brief = player getVariable ["heliOps_myMissionBrief", ""];
            private _text = "";
            if (_brief isEqualType "" && { count _brief > 0 }) then {
                _text = _brief;
            } else {
                private _mLb = _display displayCtrl 60120;
                private _idx = lbCurSel _mLb;
                _text = FAC_heliOpsGui_defaultDesc;
                if (_idx >= 0) then {
                    private _mission = FAC_heliOpsGui_missionList select _idx;
                    _text = _mission param [2, _text];
                };
            };
            if (count _text > 0) then {
                _descCtrl ctrlSetText _text;
            } else {
                _descCtrl ctrlSetText FAC_heliOpsGui_defaultDesc;
            };
        };
    };
};
