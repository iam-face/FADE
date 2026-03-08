// =============================================================================
// CQBGui.sqf — CQB Training Shoothouse GUI (client)
// =============================================================================
// Opens from cqbBoard. Config: enemy type (targets / real enemies), density
// (Low/Medium/High), civilians (FALSE/TRUE). Start drill / End drill toggles
// server spawn/despawn. Drill state (FADE_cqbDrillActive) is publicVariable'd by server.
// =============================================================================

FAC_cqbGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60500;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayCQB") then {
                systemChat "CQB GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_cqbGui_fnc", FAC_cqbGui_fnc];

            // Enemy type: Targets | Real enemies
            private _enemyList = _display displayCtrl 60501;
            lbClear _enemyList;
            _enemyList lbAdd "Targets (pop-up)";
            _enemyList lbSetData [0, "targets"];
            _enemyList lbAdd "Real enemies";
            _enemyList lbSetData [1, "enemies"];
            _enemyList lbSetCurSel 0;

            // Density: Low 20%, Medium 33%, High 50%
            private _densityList = _display displayCtrl 60502;
            lbClear _densityList;
            _densityList lbAdd "Low (20% per position)";
            _densityList lbSetData [0, "Low"];
            _densityList lbAdd "Medium (33% per position)";
            _densityList lbSetData [1, "Medium"];
            _densityList lbAdd "High (50% per position)";
            _densityList lbSetData [2, "High"];
            _densityList lbSetCurSel 1;

            // Civilians: FALSE (default) | TRUE (15% chance per spawn)
            private _civList = _display displayCtrl 60503;
            lbClear _civList;
            _civList lbAdd "FALSE";
            _civList lbSetData [0, "false"];
            _civList lbAdd "TRUE";
            _civList lbSetData [1, "true"];
            _civList lbSetCurSel 0;

            ["updateDrillButton", []] call FAC_cqbGui_fnc;
        };
        case "updateDrillButton": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_cqbDrillActive", false];
            private _btn = _display displayCtrl 60504;
            private _status = _display displayCtrl 60506;
            if (_active) then {
                _btn ctrlSetText "End drill";
                _status ctrlSetText "Drill active — use End drill to despawn all.";
            } else {
                _btn ctrlSetText "Start drill";
                _status ctrlSetText "Configure options and start drill to spawn at CQB positions.";
            }
        };
        case "drill": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_cqbDrillActive", false];
            if (_active) then {
                [player] remoteExec ["FADE_cqbEndDrill", 2];
                closeDialog 0;
            } else {
                private _enemyList = _display displayCtrl 60501;
                private _densityList = _display displayCtrl 60502;
                private _civList = _display displayCtrl 60503;
                private _enemyType = _enemyList lbData (lbCurSel _enemyList);
                private _density = _densityList lbData (lbCurSel _densityList);
                private _civStr = _civList lbData (lbCurSel _civList);
                private _civilians = _civStr == "true";
                [player, _enemyType, _density, _civilians] remoteExec ["FADE_cqbStartDrill", 2];
                closeDialog 0;
            };
        };
    };
};
