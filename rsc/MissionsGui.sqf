// =============================================================================
// MissionsGui.sqf - Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).

// [displayName, missionId, description, "Global"|"Single"] - stream is for logic; list shows [G]/[S]
private _missionListRaw = [
    ["Area of Operations", "AreaOfOperations", "Large-scale mission across a 2 km x 2 km AO. BLUFOR AI will assault 3 objectives in the sector. OPFOR defend. All units can respawn to continue the fight. [G]", "Global"],
    ["Asset Retrieval", "AssetRetrieval", "Secure intel at the site (scroll action on case), then RTB. [S]", "Single"],
    ["CAS / Fire Support", "CAS", "Engage enemy forces and support friendlies at the objective. [G]", "Global"],
    ["Cargo / Resupply", "Cargo", "Optionally pick up a sling-load cargo box, fly to friendly camp and land to complete (non-combat). [S]", "Single"],
    ["CASEVAC", "CASEVAC", "Pick up wounded squad and RTB. ACE Medical. [S]", "Single"],
    ["Clear Area", "ClearArea", "Medium-scale, assault an enemy-occupied town or camp. Destroy at least 80% of enemy to succeed [G]", "Global"],
    ["CSAR", "CSAR", "Recover a survivor at a helo crash site; RTB. [S]", "Single"],
    ["Find and Clear IEDs", "FindClearIEDs", "Locate and disarm an IED on a road near a civilian area. [S]", "Single"],
    ["Hostage", "Hostage", "Rescue hostages from urban buildings. Return all alive to base. [G]", "Global"],
    ["HVT", "HVT", "Find a high value target in urban area. Eliminate or capture. [G]", "Global"],
    ["Intercept Convoy", "InterceptConvoy", "Destroy convoy before it reaches the end zone. [G]", "Global"],
    ["Mass Casualty (MassCas)", "MASCAS", "3–6 BLUFOR with injuries at the base medical area. [S], ACE", "Single"],
    ["Mass Casualty (MassCas) KAT", "MASCASKAT", "3–6 BLUFOR with injuries at the base medical area. Heal all. [S], KAT", "Single"],
    ["Medical", "Medical", "One BLUFOR with injury at the base medical area. [S], ACE", "Single"],
    ["Medical KAT", "MedicalKAT", "One BLUFOR with injury at the base medical area. [S], KAT", "Single"],
    ["Mine Clearing", "MineClearing", "Clear 5–10 mines in a 200 m area. Complete when all disarmed. [S]", "Single"],
    ["Operation", "Operation", "Capture multiple civ zones concurrently; 60s tick, OPFOR can recapture. [G]", "Global"],
    ["Search & Destroy", "SearchDestroy", "Find and clear 3 OPFOR buildings in a civ town. [G]", "Global"],
    ["Troop Extract", "TroopExtract", "Fly to pickup zone, land to load squad, return to base. [S]", "Single"],
    ["Troop Insert", "TroopInsert", "Pick up squad at base, fly to LZ, land to disembark. [S]", "Single"]
];
private _sorted = [_missionListRaw, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
if (isNil "_sorted" || { !(_sorted isEqualType []) }) then { _sorted = _missionListRaw };
missionNamespace setVariable ["FAC_missionsGui_missionList", _sorted];

// Default intro when no mission selected
FAC_missionsGui_defaultDesc = "Select a mission from the list to view details. After you start one, this area shows pickup, objectives, and completion criteria from your task briefing.";

// Remove first line of server brief when it duplicates the mission type already shown in "OpName (Type)" header.
FAC_missionsGui_stripDuplicateBriefHeader = {
    params ["_brief", "_missionTypeLabel", "_missionTypeId"];
    private _nl = toString [10];
    private _lines = _brief splitString _nl;
    if (count _lines == 0) exitWith { _brief };
    private _first = _lines select 0;
    if (_first == "") exitWith { _brief };
    private _firstU = toUpper _first;
    private _labelU = toUpper _missionTypeLabel;
    private _strip = false;
    if (_missionTypeLabel != "" && { _firstU == _labelU }) then {
        _strip = true;
    } else {
        if (_missionTypeId == "FindClearIEDs" && { _firstU find "FIND AND CLEAR IED" == 0 }) then {
            _strip = true;
        };
    };
    if (!_strip) exitWith { _brief };
    _lines deleteAt 0;
    while { count _lines > 0 && { (_lines select 0) == "" } } do { _lines deleteAt 0 };
    if (count _lines == 0) exitWith { "" };
    _lines joinString _nl
};

FADE_receiveCopilotState = {
    // Kept for compatibility with server RPC; copilot controls were removed from this dialog.
    params [["_hasCopilot", false]];
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
            missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];

            // Mission list: [G] or [S] prefix, then displayName
            private _mLb = _display displayCtrl 60120;
            lbClear _mLb;
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            {
                _x params [["_name", ""], ["_id", ""], ["_desc", ""], ["_stream", "Single"]];
                private _tag = if (_stream == "Global") then {"[G] "} else {"[S] "};
                private _idx = _mLb lbAdd (_tag + _name);
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
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "headerRefresh": {
            ["refreshStatus", []] call FAC_missionsGui_fnc;
        };
        case "abortSlot": {
            if (isNull _display) exitWith {};
            private _slot = toUpper ((_params param [0, ""]) + "");
            if !(_slot in ["G1", "S1", "S2", "S3"]) exitWith {};
            private _btnIdc = switch _slot do {
                case "G1": { 60150 };
                case "S1": { 60151 };
                case "S2": { 60152 };
                default { 60153 };
            };
            private _btn = _display displayCtrl _btnIdc;
            private _pending = missionNamespace getVariable ["FAC_missions_abortSlotPending", ["", -99]];
            private _pendingSlot = _pending param [0, ""];
            private _pendingTime = _pending param [1, -99];
            if (_pendingSlot != _slot || { time - _pendingTime > 3 }) then {
                missionNamespace setVariable ["FAC_missions_abortSlotPending", [_slot, time]];
                _btn ctrlSetText ("CONFIRM " + _slot + "?");
                _btn ctrlSetTextColor [1, 0.35, 0.35, 1];
                [] spawn {
                    sleep 3;
                    private _st = missionNamespace getVariable ["FAC_missions_abortSlotPending", ["", -99]];
                    if ((_st param [0, ""]) != "") then {
                        missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];
                        if (!isNull (findDisplay 60002)) then {
                            { ((findDisplay 60002) displayCtrl _x) ctrlSetTextColor [1, 1, 1, 1] } forEach [60150, 60151, 60152, 60153];
                            ((findDisplay 60002) displayCtrl 60150) ctrlSetText "Abort G1";
                            ((findDisplay 60002) displayCtrl 60151) ctrlSetText "Abort S1";
                            ((findDisplay 60002) displayCtrl 60152) ctrlSetText "Abort S2";
                            ((findDisplay 60002) displayCtrl 60153) ctrlSetText "Abort S3";
                        };
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];
                { ((findDisplay 60002) displayCtrl _x) ctrlSetTextColor [1, 1, 1, 1] } forEach [60150, 60151, 60152, 60153];
                ((findDisplay 60002) displayCtrl 60150) ctrlSetText "Abort G1";
                ((findDisplay 60002) displayCtrl 60151) ctrlSetText "Abort S1";
                ((findDisplay 60002) displayCtrl 60152) ctrlSetText "Abort S2";
                ((findDisplay 60002) displayCtrl 60153) ctrlSetText "Abort S3";
                [_slot, player] remoteExec ["FADE_abortMissionSlot", 2];
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
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
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
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
            private _entryTitle = {
                params ["_entry"];
                private _type = _entry param [0, ""];
                private _operationName = _entry param [4, ""];
                if (_operationName isEqualType "" && { _operationName != "" }) exitWith { _operationName };
                [_type] call _displayName
            };
            private _entryTypeLabel = {
                params ["_entry"];
                private _type = _entry param [0, ""];
                [_type] call _displayName
            };
            private _ownerStr = {
                params ["_o"];
                if (!isNull _o) then { name _o } else { "?" }
            };
            private _nl = toString [10];
            private _slotGlobal = _display displayCtrl 60130;
            if (!isNull _slotGlobal) then {
                if (count _global >= 2) then {
                    private _title = [_global] call _entryTitle;
                    private _typeLabel = [_global] call _entryTypeLabel;
                    private _owner = _global select 1;
                    private _oStr = [_owner] call _ownerStr;
                    _slotGlobal ctrlSetText (_title + _nl + _typeLabel + _nl + "Started by: " + _oStr);
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
                        _entry params ["", "_o"];
                        private _n = [_entry] call _entryTitle;
                        private _typeLabel = [_entry] call _entryTypeLabel;
                        private _oStr = [_o] call _ownerStr;
                        _c ctrlSetText (_n + _nl + _typeLabel + _nl + "Started by: " + _oStr);
                    } else {
                        _c ctrlSetText ("No mission in this slot.");
                    };
                    _c ctrlEnable false;
                };
            } forEach _singleIdcs;
            private _gAbort = _display displayCtrl 60150;
            if (!isNull _gAbort) then { _gAbort ctrlEnable (count _global >= 2) };
            {
                private _btn = _display displayCtrl _x;
                if (!isNull _btn) then {
                    _btn ctrlEnable (count _singleList > _forEachIndex);
                };
            } forEach [60151, 60152, 60153];
            ["refreshDescription", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _missionLb = _display displayCtrl 60120;
            private _startBtn = _display displayCtrl 60121;
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
            private _operationNameForPlayer = {
                private _uid = getPlayerUID player;
                private _global = missionNamespace getVariable ["FADE_globalMission", []];
                if (
                    count _global >= 5 &&
                    {
                        (_global param [1, objNull]) == player ||
                        { (_global param [3, ""]) == _uid }
                    }
                ) exitWith { _global param [4, ""] };
                private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
                private _idx = _singleList findIf {
                    (_x param [1, objNull]) == player ||
                    { (_x param [3, ""]) == _uid }
                };
                if (_idx >= 0) exitWith { (_singleList select _idx) param [4, ""] };
                ""
            };
            private _brief = player getVariable ["FADE_myMissionBrief", ""];
            private _text = "";
            if (_brief isEqualType "" && { count _brief > 0 }) then {
                _text = _brief;
                private _opName = [] call _operationNameForPlayer;
                if (_opName != "") then {
                    private _missionTypeId = player getVariable ["FADE_myMission", ""];
                    private _missionTypeLabel = _missionTypeId;
                    if (_missionTypeId != "") then {
                        private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
                        {
                            if ((_x select 1) == _missionTypeId) exitWith {
                                _missionTypeLabel = _x select 0;
                            };
                        } forEach _list;
                    };
                    _text = [_text, _missionTypeLabel, _missionTypeId] call FAC_missionsGui_stripDuplicateBriefHeader;
                    _text = format ["%1 (%2)%3%3%4", _opName, _missionTypeLabel, toString [10], _text];
                };
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
            _descCtrl ctrlEnable false;
        };
    };
};
