// =============================================================================
// MissionsGui.sqf - Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).

// [displayName, missionId, description, "Global"|"Single"] - stream is for logic; list shows [G]/[S]
// Keep [0]/[1] in sync with rsc/FAC_MissionTypeLabels.sqf (server mission intro subtitle).
private _missionListRaw = [
    ["Area of Operations", "AreaOfOperations", "Shared fight across a wide sector with multiple objectives. Expect steady contact and space to manoeuvre. [G]", "Global"],
    ["Asset Retrieval", "AssetRetrieval", "Recover priority equipment from enemy-held ground. Expect guarded routes, patrols and buildings; plan your extraction. [G]", "Global"],
    ["CAS / Fire Support", "CAS", "Provide close air or indirect fires to support friendly forces under attack. Identify friendlies and deconflict before engaging. [G]", "Global"],
    ["Cargo / Resupply", "Cargo", "Deliver supplies to a forward camp. Land to unload or practice sling loads. Follow PZ and LZ procedures. [S]", "Single"],
    ["CASEVAC", "CASEVAC", "Evacuate wounded from the field to medical care. Fast, careful pickups; LZs may be tight or informal. [S]", "Single"],
    ["Clear Area", "ClearArea", "Clear and secure an enemy-held town or camp. Expect close fighting and reinforced positions. [G]", "Global"],
    ["CSAR", "CSAR", "Search and recover personnel from a crash site. Treat the area as dangerous until secured. [G]", "Global"],
    ["Escape & Evasion", "EscapeEvasion", "Move separated personnel out of hostile territory while a rescue force coordinates recovery. Navigate with limited aids. [G]", "Global"],
    ["Hostage", "Hostage", "Rescue civilians held by hostiles in dense terrain. Move fast, control the scene, and separate civilians from combatants. [G]", "Global"],
    ["HVT", "HVT", "Locate and neutralise or capture a priority target in built-up areas. Secure the target and extract them to base. [G]", "Global"],
    ["Intercept Convoy", "InterceptConvoy", "Ambush and stop a moving enemy column before it reaches its destination. Expect escorts and rapid reactions. [G]", "Global"],
    ["Mine Clearing", "MineClearing", "Clear a short road segment of mines or IEDs. Use deliberate recon and proven clearance procedures. [S]", "Single"],
    ["Operation", "Operation", "Linked fights across several zones. Clear, hold, and prevent enemy movement between areas. [G]", "Global"],
    ["Search & Destroy", "SearchDestroy", "Search a marked zone for enemy ammo caches (burning barrels mark sites). Task states how many to find and what % must be destroyed. [G]", "Global"],
    ["Troop Extract", "TroopExtract", "Pick up a ground team and return them to base. LZ discipline and calm loading are essential. [S]", "Single"],
    ["Troop Insert", "TroopInsert", "Insert troops into a surveyed LZ from base. Aim for clear, safe landings and quick dismounts. [S]", "Single"]
];
private _sorted = [_missionListRaw, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
if (isNil "_sorted" || { !(_sorted isEqualType []) }) then { _sorted = _missionListRaw };
missionNamespace setVariable ["FAC_missionsGui_missionList", _sorted];

// Default intro when no mission selected
FAC_missionsGui_defaultDesc = "Select a mission to see the commander’s intent and expected tasks. After you start, check your Tasks panel and map markers for full orders, grids, and completion criteria.";

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
        if (_missionTypeId == "MineClearing" && { _firstU find "MINE / EOD CLEARANCE" == 0 }) then {
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
            if !(["FAC_playerCanUseMissionsGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Missions GUI access denied by lobby settings.";
            };
            if (!createDialog "RscDisplayMissions") then {
                systemChat "MISSIONS GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60002;
            if (isNull _display) exitWith {};
            if (!isNil "FAC_escapeEvasionPickGui_fnc_destroyOverlay") then { [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay };
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
            if (_missionType == "EscapeEvasion") exitWith {
                if (isNil "FAC_escapeEvasionPickGui_fnc") exitWith { systemChat "ESCAPE & EVASION UI not loaded."; };
                ["open", []] call FAC_escapeEvasionPickGui_fnc;
            };
            if (_missionType == "TroopInsert") exitWith {
                if (isNil "FAC_missionLocationPickGui_fnc") exitWith { systemChat "MISSION: location picker not loaded."; };
                ["open", [_missionType]] call FAC_missionLocationPickGui_fnc;
            };
            if (isNil "FAC_missionLocationPickGui_fnc") exitWith { systemChat "MISSION: location picker not loaded."; };
            ["open", [_missionType]] call FAC_missionLocationPickGui_fnc;
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
                // If an operation name is provided, prefer "Operation <name>" as the title.
                if (!(_operationName isEqualType "") && { _operationName != "" }) exitWith { format ["Operation %1", _operationName] };
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
            private _slotFocusLine = {
                params ["_entry"];
                if (count _entry < 3) exitWith { "Focus: see Tasks / markers." };
                private _mType = _entry param [0, ""];
                private _pos = _entry param [2, []];
                if (_mType == "InterceptConvoy") exitWith { "Route: start and end markers  -  full orders in Tasks." };
                if (_mType == "Operation") exitWith { "AO: multiple zones  -  capture rules in Tasks." };
                if (_pos isEqualType [] && { count _pos >= 2 } && { !(_pos isEqualTo [0, 0, 0]) }) exitWith {
                    "Approx. area grid: " + (mapGridPosition _pos) + "  -  detail in Tasks."
                };
                "Focus: see Tasks / markers."
            };
            private _nl = toString [10];
            private _slotGlobal = _display displayCtrl 60130;
            if (!isNull _slotGlobal) then {
                if (count _global >= 2) then {
                    private _title = [_global] call _entryTitle;
                    private _typeLabel = [_global] call _entryTypeLabel;
                    private _owner = _global select 1;
                    private _oStr = [_owner] call _ownerStr;
                    private _focus = [_global] call _slotFocusLine;
                    _slotGlobal ctrlSetText (_title + _nl + _typeLabel + _nl + _focus + _nl + "Started by: " + _oStr);
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
                        private _focus = [_entry] call _slotFocusLine;
                        _c ctrlSetText (_n + _nl + _typeLabel + _nl + _focus + _nl + "Started by: " + _oStr);
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
        // Description: shows *your* FADE_myMissionBrief (short grid + intent + “see Tasks”) while active; otherwise
        // the list-row preview blurb. Does not merge multiple active missions.
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
                        _text = format ["Operation %1 \u2014 %2%3%3%4", _opName, _missionTypeLabel, toString [10], _text];
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
