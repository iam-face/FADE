// =============================================================================
// CQBGui.sqf - CQB Training Shoothouse GUI (client)
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

            private _info = _display displayCtrl 60507;
            private _n = missionNamespace getVariable ["FADE_cqbPosCount", -1];
            private _nStr = if (_n >= 0) then { str _n } else { "-" };
            private _nl = toString [10];
            private _txt = format [
                "Selection%1" +
                "• Targets - pop-up range targets.%1" +
                "• Real enemies - spawns OPFOR units.%1%1" +
                "Density%1" +
                "Chance each CQB position rolls a spawn, depending on your spawn density selection: Low 20%%, Medium 33%%, High 50%%.%1%1" +
                "Civilians%1" +
                "If TRUE, 15%% chance per spawn roll for a civilian instead of an enemy.%1%1" +
                "End state%1" +
                "With real enemies, drill will auto-complete when all hostiles are eliminated or captive. Anyone can end the drill via this GUI.%1%1" +
                "Good luck.",
                _nl,
                _nStr
            ];
            _info ctrlSetText _txt;

            ["updateDrillButton", []] call FAC_cqbGui_fnc;
        };
        case "updateDrillButton": {
            _display = findDisplay 60500;
            if (isNull _display) exitWith {};
            private _active = missionNamespace getVariable ["FADE_cqbDrillActive", false];
            private _btn = _display displayCtrl 60504;
            if (_active) then {
                _btn ctrlSetText "End drill";
            } else {
                _btn ctrlSetText "Start drill";
            };
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
