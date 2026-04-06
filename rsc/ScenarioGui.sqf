// =============================================================================
// ScenarioGui.sqf - Scenario settings (weather, time, factions)
// =============================================================================
// Allows players to manage scenario-wide settings: weather, time of day,
// enemy faction, friendly faction, civilian faction. Other scripts use these
// choices for unit spawning (Missions.sqf, AmbientCivilians.sqf).
// =============================================================================

// Time: military format 0000–2300 (24 hours). [[displayStr, hour], ...]
FAC_scenarioGui_timeList = [];
for "_h" from 0 to 23 do {
    private _str = if (_h < 10) then { "0" + str _h } else { str _h };
    _str = _str + "00";
    FAC_scenarioGui_timeList pushBack [_str, _h];
};

// Weather presets
FAC_scenarioGui_weatherPresets = [
    ["Clear", "Clear"],
    ["Overcast", "Overcast"],
    ["Foggy", "Foggy"],
    ["Rain", "Rain"],
    ["Storm", "Storm"],
    ["Face Mission", "FaceMission"]
];

// Get faction display name (reuse LoadoutGui if available)
FAC_scenarioGui_getFactionDisplayName = {
    params ["_faction"];
    if (_faction == "") exitWith { "Unknown" };
    if (!isNil "FAC_loadoutGui_getFactionDisplayName") exitWith { [_faction] call FAC_loadoutGui_getFactionDisplayName };
    private _dn = getText (configFile >> "CfgFactionClasses" >> _faction >> "displayName");
    if (_dn != "") exitWith { _dn };
    (_faction splitString "_") joinString " "
};

// Build list of factions for a given side (0=East, 1=West, 2=Independent, 3=Civilian)
// Returns: [[factionId, displayName], ...]
FAC_scenarioGui_getFactionsForSide = {
    params ["_sideNum"];
    private _result = [];
    {
        private _faction = configName _x;
        if (getNumber (_x >> "side") == _sideNum) then {
            private _dn = getText (_x >> "displayName");
            if (_dn == "") then { _dn = _faction };
            _result pushBack [_faction, _dn];
        };
    } forEach ("true" configClasses (configFile >> "CfgFactionClasses"));
    _result = _result apply { [_x select 1, _x select 0] };
    _result sort true;
    _result = _result apply { [_x select 1, _x select 0] };
    _result
};

// Admin dialog cleanup buttons: idc + default label (first click arms "Are you sure?" + red text, like Missions abort)
FAC_scenarioGui_adminCleanupButtonDefs = [
    ["makeZeus", 60435, "Make me Zeus"],
    ["removeMyZeus", 60436, "Remove my Zeus"],
    ["teleportAllToBase", 60437, "Teleport all players to HQ (teleportBase)"],
    ["stopAllMusic", 60438, "Stop all music (jukebox)"],
    ["abortAllMissions", 60430, "Abort all missions"],
    ["despawnCivilians", 60431, "Despawn civilians"],
    ["despawnOpfor", 60432, "Despawn OPFOR"]
];

FAC_scenarioGui_adminResetCleanupButtons = {
    private _display = findDisplay 60004;
    if (isNull _display) exitWith {};
    {
        _x params ["_action", "_idc", "_text"];
        private _ctrl = _display displayCtrl _idc;
        if (!isNull _ctrl) then {
            _ctrl ctrlSetText _text;
            _ctrl ctrlSetTextColor [1, 1, 1, 1];
        };
    } forEach FAC_scenarioGui_adminCleanupButtonDefs;
};

FAC_scenarioGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60003;
    private _displayAdmin = findDisplay 60004;
    if (isNull _display && { isNull _displayAdmin } && { !(_action in ["open", "openAdmin"]) }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayScenario") then {
                systemChat "SCENARIO GUI: RESOURCE NOT FOUND.";
            };
        };
        case "openAdmin": {
            if (!isNull (findDisplay 60003)) then { closeDialog 0; };
            if (!createDialog "RscDisplayScenarioAdmin") then {
                systemChat "SCENARIO ADMIN GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60003;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_scenarioGui_fnc", FAC_scenarioGui_fnc];

            // Time list
            private _timeList = _display displayCtrl 60301;
            lbClear _timeList;
            private _currentHour = missionNamespace getVariable ["FADE_scenarioTime", 18];
            private _timeSel = 0;
            {
                _x params ["_name", "_hour"];
                private _idx = _timeList lbAdd _name;
                _timeList lbSetData [_idx, str _hour];
                if (_hour == _currentHour) then { _timeSel = _idx };
            } forEach FAC_scenarioGui_timeList;
            if (lbSize _timeList > 0) then { _timeList lbSetCurSel _timeSel };

            // Weather list
            private _weatherList = _display displayCtrl 60302;
            lbClear _weatherList;
            private _currentWeather = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
            private _weatherSel = 0;
            {
                _x params ["_name", "_id"];
                private _idx = _weatherList lbAdd _name;
                _weatherList lbSetData [_idx, _id];
                if (_id == _currentWeather) then { _weatherSel = _idx };
            } forEach FAC_scenarioGui_weatherPresets;
            if (lbSize _weatherList > 0) then { _weatherList lbSetCurSel _weatherSel };

            // Friendly factions (BLUFOR = side 1) - first column
            private _friendlyList = _display displayCtrl 60311;
            lbClear _friendlyList;
            private _friendlyFactions = [1] call FAC_scenarioGui_getFactionsForSide;
            private _currentFriendly = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
            private _friendlySel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _friendlyList lbAdd _dn;
                _friendlyList lbSetData [_idx, _faction];
                if (_faction == _currentFriendly) then { _friendlySel = _idx };
            } forEach _friendlyFactions;
            if (lbSize _friendlyList > 0) then { _friendlyList lbSetCurSel _friendlySel };

            // Enemy factions (OPFOR = side 0) - second column
            private _enemyList = _display displayCtrl 60310;
            lbClear _enemyList;
            private _enemyFactions = [0] call FAC_scenarioGui_getFactionsForSide;
            private _currentEnemy = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
            private _enemySel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _enemyList lbAdd _dn;
                _enemyList lbSetData [_idx, _faction];
                if (_faction == _currentEnemy) then { _enemySel = _idx };
            } forEach _enemyFactions;
            if (lbSize _enemyList > 0) then { _enemyList lbSetCurSel _enemySel };

            // Civilian factions (side 3) - third column
            private _civList = _display displayCtrl 60312;
            lbClear _civList;
            private _civFactions = [3] call FAC_scenarioGui_getFactionsForSide;
            private _currentCiv = missionNamespace getVariable ["FADE_scenarioCivFaction", "CIV_F"];
            private _civSel = 0;
            {
                _x params ["_faction", "_dn"];
                private _idx = _civList lbAdd _dn;
                _civList lbSetData [_idx, _faction];
                if (_faction == _currentCiv) then { _civSel = _idx };
            } forEach _civFactions;
            if (lbSize _civList > 0) then { _civList lbSetCurSel _civSel };

            // Limit gear to chosen BLUFOR faction (TRUE / FALSE)
            private _limitGearList = _display displayCtrl 60315;
            lbClear _limitGearList;
            _limitGearList lbAdd "FALSE";
            _limitGearList lbSetData [0, "false"];
            _limitGearList lbAdd "TRUE";
            _limitGearList lbSetData [1, "true"];
            private _currentLimit = missionNamespace getVariable ["FADE_limitGearToFriendlyFaction", false];
            _limitGearList lbSetCurSel (if (_currentLimit) then { 1 } else { 0 });

            // Ambient enemy patrols (OFF / ON)
            private _patrolsList = _display displayCtrl 60316;
            lbClear _patrolsList;
            _patrolsList lbAdd "OFF";
            _patrolsList lbSetData [0, "false"];
            _patrolsList lbAdd "ON";
            _patrolsList lbSetData [1, "true"];
            private _currentPatrols = missionNamespace getVariable ["FADE_scenarioPatrols", false];
            _patrolsList lbSetCurSel (if (_currentPatrols) then { 1 } else { 0 });

            // Enemy AI skill: 0, 0.1, 0.2, ... 1.0 (inclusive)
            private _skillList = _display displayCtrl 60317;
            lbClear _skillList;
            for "_s" from 0 to 10 do {
                private _val = _s / 10;
                private _str = if (_s == 10) then { "1" } else { "0." + str _s };
                private _idx = _skillList lbAdd _str;
                _skillList lbSetData [_idx, str _val];
            };
            private _currentSkill = missionNamespace getVariable ["FADE_enemySkill", 0.2];
            private _skillSel = (round (_currentSkill * 10)) min 10 max 0;
            _skillList lbSetCurSel _skillSel;

            // Enemy routing: retreat/flee (OFF = allowFleeing 0, ON = 0.5). Governs all enemy spawns (missions, AAA, patrols).
            private _routingList = _display displayCtrl 60318;
            lbClear _routingList;
            _routingList lbAdd "OFF";
            _routingList lbSetData [0, "0"];
            _routingList lbAdd "ON";
            _routingList lbSetData [1, "0.5"];
            private _currentRouting = missionNamespace getVariable ["FADE_enemyRouting", 0];
            _routingList lbSetCurSel (if (_currentRouting > 0) then { 1 } else { 0 });

            // Enemy AAA level (None / Light / Medium / MANPADS / Heavy)
            private _aaaList = _display displayCtrl 60319;
            lbClear _aaaList;
            { _aaaList lbAdd _x; _aaaList lbSetData [_forEachIndex, _x] } forEach ["None", "Light", "Medium", "MANPADS", "Heavy"];
            private _currentAAA = missionNamespace getVariable ["FADE_enemyAAALevel", "None"];
            private _aaaSel = 0;
            { if (_x == _currentAAA) exitWith { _aaaSel = _forEachIndex } } forEach ["None", "Light", "Medium", "MANPADS", "Heavy"];
            _aaaList lbSetCurSel _aaaSel;

            // OPFOR AT launchers (secondary slot; MANPADS AA excluded) — same column as former AO strength
            private _launcherList = _display displayCtrl 60324;
            lbClear _launcherList;
            private _launcherChoices = [
                ["Normal (keep all)", "Normal"],
                ["Reduced (~25% keep)", "Reduced"],
                ["Minimal (~10% keep)", "Minimal"],
                ["None (strip all AT)", "None"]
            ];
            {
                _x params ["_label", "_value"];
                private _idx = _launcherList lbAdd _label;
                _launcherList lbSetData [_idx, _value];
            } forEach _launcherChoices;
            private _currentLauncher = missionNamespace getVariable ["FADE_opforLauncherSetting", "Normal"];
            private _launcherSel = 0;
            { if ((_x select 1) == _currentLauncher) exitWith { _launcherSel = _forEachIndex } } forEach _launcherChoices;
            _launcherList lbSetCurSel _launcherSel;

            // OPFOR ambient air (P24): off / capped + cooldown spawns toward BLUFOR
            private _opforAirList = _display displayCtrl 60328;
            lbClear _opforAirList;
            private _opforAirChoices = [
                ["Off", "Off"],
                ["Low (max 1, 10 min between)", "Low"],
                ["Medium (max 2, 5 min between)", "Medium"]
            ];
            {
                _x params ["_label", "_value"];
                private _idx = _opforAirList lbAdd _label;
                _opforAirList lbSetData [_idx, _value];
            } forEach _opforAirChoices;
            private _currentAir = missionNamespace getVariable ["FADE_opforAirSetting", "Off"];
            private _airSel = 0;
            { if ((_x select 1) == _currentAir) exitWith { _airSel = _forEachIndex } } forEach _opforAirChoices;
            _opforAirList lbSetCurSel _airSel;

            // Operation mission: number of enemy-held civ zones (2–10)
            private _opZonesList = _display displayCtrl 60329;
            lbClear _opZonesList;
            for "_z" from 2 to 10 do {
                private _idx = _opZonesList lbAdd (str _z + " towns");
                _opZonesList lbSetData [_idx, str _z];
            };
            private _currentOpZones = missionNamespace getVariable ["FADE_operationZoneCount", 6];
            _currentOpZones = (round _currentOpZones) max 2 min 10;
            _opZonesList lbSetCurSel (_currentOpZones - 2);

            // OPFOR population scale (auto/manual)
            private _opforPopList = _display displayCtrl 60327;
            lbClear _opforPopList;
            private _opforChoices = [
                ["Auto", "Auto"],
                ["Very Low (0.25x)", "VeryLow"],
                ["Low (0.5x)", "Low"],
                ["Normal (1x)", "Normal"],
                ["High (1.5x)", "High"],
                ["Very High (2x)", "VeryHigh"],
                ["Insane (4x)", "Insane"]
            ];
            {
                _x params ["_label", "_value"];
                private _idx = _opforPopList lbAdd _label;
                _opforPopList lbSetData [_idx, _value];
            } forEach _opforChoices;
            private _currentOpforPop = missionNamespace getVariable ["FADE_opforPopulationSetting", "Normal"];
            private _opforSel = 3;
            {
                if ((_x select 1) == _currentOpforPop) exitWith { _opforSel = _forEachIndex };
            } forEach _opforChoices;
            _opforPopList lbSetCurSel _opforSel;

            // Time compression (pseudo): server advances date by extra time on a fixed loop (GUI: 1x / 5x / 25x)
            private _timeScaleChoices = [["1x", 1], ["5x", 5], ["25x", 25]];
            private _timeCompressionList = _display displayCtrl 60325;
            lbClear _timeCompressionList;
            {
                _x params ["_label", "_scale"];
                private _idx = _timeCompressionList lbAdd _label;
                _timeCompressionList lbSetData [_idx, str _scale];
            } forEach _timeScaleChoices;
            private _currentTimeScale = missionNamespace getVariable ["FADE_timeCompressionScale", 1];
            private _timeScaleSel = 0;
            {
                _x params ["_label", "_scale"];
                if (_scale == _currentTimeScale) exitWith { _timeScaleSel = _forEachIndex };
            } forEach _timeScaleChoices;
            if (_currentTimeScale > 25) then { _timeScaleSel = 2 };
            if (_currentTimeScale > 5 && _currentTimeScale < 25) then { _timeScaleSel = 1 };
            _timeCompressionList lbSetCurSel _timeScaleSel;

            // Teleport-to-player access mode
            private _tpPlayerModeList = _display displayCtrl 60326;
            lbClear _tpPlayerModeList;
            _tpPlayerModeList lbAdd "All players";
            _tpPlayerModeList lbSetData [0, "0"];
            _tpPlayerModeList lbAdd "SL only [admin/Zeus override]";
            _tpPlayerModeList lbSetData [1, "1"];
            private _tpPlayerMode = missionNamespace getVariable ["FADE_teleportToPlayerMode", 0];
            _tpPlayerModeList lbSetCurSel (if (_tpPlayerMode > 0) then { 1 } else { 0 });

            // Civilians enabled (governs all ambient civilians)
            private _civEnabledList = _display displayCtrl 60322;
            lbClear _civEnabledList;
            _civEnabledList lbAdd "TRUE";
            _civEnabledList lbSetData [0, "true"];
            _civEnabledList lbAdd "FALSE";
            _civEnabledList lbSetData [1, "false"];
            private _civEnabled = missionNamespace getVariable ["FADE_civiliansEnabled", true];
            _civEnabledList lbSetCurSel (if (_civEnabled) then { 0 } else { 1 });

            // Limit to CTB loadouts (TRUE / FALSE)
            private _ctbOnlyList = _display displayCtrl 60323;
            lbClear _ctbOnlyList;
            _ctbOnlyList lbAdd "FALSE";
            _ctbOnlyList lbSetData [0, "false"];
            _ctbOnlyList lbAdd "TRUE";
            _ctbOnlyList lbSetData [1, "true"];
            private _ctbOnly = missionNamespace getVariable ["FADE_limitToCtbLoadouts", false];
            _ctbOnlyList lbSetCurSel (if (_ctbOnly) then { 1 } else { 0 });

            private _adminBtns = [60330];
            {
                private _ctrl = _display displayCtrl _x;
                if (!isNull _ctrl) then {
                    _ctrl ctrlEnable true;
                    _ctrl ctrlSetFade 0;
                    _ctrl ctrlCommit 0;
                };
            } forEach _adminBtns;
        };
        case "headerRefresh": {
            if (!isNull (findDisplay 60004)) then {
                ["onLoadAdmin", []] call FAC_scenarioGui_fnc;
            } else {
                ["onLoad", []] call FAC_scenarioGui_fnc;
            };
        };
        case "onLoadAdmin": {
            private _display = findDisplay 60004;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
            missionNamespace setVariable ["FAC_scenario_adminConfirmGen", 0];
            [] call FAC_scenarioGui_adminResetCleanupButtons;
            {
                private _ctrl = _display displayCtrl _x;
                if (!isNull _ctrl) then {
                    _ctrl ctrlEnable true;
                    _ctrl ctrlSetFade 0;
                    _ctrl ctrlCommit 0;
                };
            } forEach [60430, 60431, 60432, 60435, 60436, 60437, 60438];
        };
        case "adminCleanup": {
            if (isNull (findDisplay 60004)) exitWith {};
            private _cleanupAction = (_params param [0, ""]) + "";
            if (_cleanupAction == "") exitWith {};
            private _display = findDisplay 60004;
            private _state = missionNamespace getVariable ["FAC_scenario_adminPending", ["", -99]];
            private _pendingAction = _state param [0, ""];
            private _pendingTime = _state param [1, -99];
            if (_pendingAction != _cleanupAction || { time - _pendingTime > 3 }) then {
                private _confirmGen = (missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) + 1;
                missionNamespace setVariable ["FAC_scenario_adminConfirmGen", _confirmGen];
                missionNamespace setVariable ["FAC_scenario_adminPending", [_cleanupAction, time]];
                {
                    _x params ["_act", "_idc", "_txt"];
                    private _ctrl = _display displayCtrl _idc;
                    if (!isNull _ctrl) then {
                        if (_act == _cleanupAction) then {
                            _ctrl ctrlSetText "Are you sure?";
                            _ctrl ctrlSetTextColor [1, 0.35, 0.35, 1];
                        } else {
                            _ctrl ctrlSetText _txt;
                            _ctrl ctrlSetTextColor [1, 1, 1, 1];
                        };
                    };
                } forEach FAC_scenarioGui_adminCleanupButtonDefs;
                [_confirmGen] spawn {
                    params ["_gen"];
                    sleep 3;
                    if ((missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) != _gen) exitWith {};
                    private _st = missionNamespace getVariable ["FAC_scenario_adminPending", ["", -99]];
                    if ((_st param [0, ""]) != "") then {
                        missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
                        if (!isNull (findDisplay 60004)) then {
                            [] call FAC_scenarioGui_adminResetCleanupButtons;
                        };
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_scenario_adminConfirmGen", (missionNamespace getVariable ["FAC_scenario_adminConfirmGen", 0]) + 1];
                missionNamespace setVariable ["FAC_scenario_adminPending", ["", -99]];
                [] call FAC_scenarioGui_adminResetCleanupButtons;
                [_cleanupAction, player] remoteExec ["FADE_adminCleanupAction", 2];
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
        };
        case "apply": {
            if (isNull _display) exitWith {};
            private _timeList = _display displayCtrl 60301;
            private _weatherList = _display displayCtrl 60302;
            private _friendlyList = _display displayCtrl 60311;
            private _enemyList = _display displayCtrl 60310;
            private _civList = _display displayCtrl 60312;
            private _limitGearList = _display displayCtrl 60315;
            private _patrolsList = _display displayCtrl 60316;
            private _skillList = _display displayCtrl 60317;
            private _routingList = _display displayCtrl 60318;
            private _aaaList = _display displayCtrl 60319;
            private _launcherList = _display displayCtrl 60324;
            private _opforAirList = _display displayCtrl 60328;
            private _opZonesList = _display displayCtrl 60329;
            private _opforPopList = _display displayCtrl 60327;
            private _timeCompressionList = _display displayCtrl 60325;
            private _civEnabledList = _display displayCtrl 60322;
            private _ctbOnlyList = _display displayCtrl 60323;
            private _tpPlayerModeList = _display displayCtrl 60326;

            private _hour = 18;
            if (lbCurSel _timeList >= 0) then { _hour = parseNumber (_timeList lbData (lbCurSel _timeList)) };
            private _weather = "Clear";
            if (lbCurSel _weatherList >= 0) then { _weather = _weatherList lbData (lbCurSel _weatherList) };
            private _friendlyFaction = "BLU_F";
            if (lbCurSel _friendlyList >= 0) then { _friendlyFaction = _friendlyList lbData (lbCurSel _friendlyList) };
            private _enemyFaction = "OPF_F";
            if (lbCurSel _enemyList >= 0) then { _enemyFaction = _enemyList lbData (lbCurSel _enemyList) };
            private _civFaction = "CIV_F";
            if (lbCurSel _civList >= 0) then { _civFaction = _civList lbData (lbCurSel _civList) };
            private _limitGear = false;
            if (lbCurSel _limitGearList >= 0) then { _limitGear = (_limitGearList lbData (lbCurSel _limitGearList)) == "true" };
            private _patrolsEnabled = false;
            if (lbCurSel _patrolsList >= 0) then { _patrolsEnabled = (_patrolsList lbData (lbCurSel _patrolsList)) == "true" };
            private _enemySkill = 0.2;
            if (lbCurSel _skillList >= 0) then { _enemySkill = parseNumber (_skillList lbData (lbCurSel _skillList)) };
            private _enemyRouting = 0;
            if (lbCurSel _routingList >= 0) then { _enemyRouting = parseNumber (_routingList lbData (lbCurSel _routingList)) };
            private _enemyAAA = "None";
            if (lbCurSel _aaaList >= 0) then { _enemyAAA = _aaaList lbData (lbCurSel _aaaList) };
            // AO mission strength: not in GUI — keep missionNamespace / Config (FADE_aoStrength)
            private _aoStrength = missionNamespace getVariable ["FADE_aoStrength", "Medium"];
            if (_aoStrength == "Mid") then { _aoStrength = "Medium" };
            private _opforPopulationSetting = "Normal";
            if (lbCurSel _opforPopList >= 0) then { _opforPopulationSetting = _opforPopList lbData (lbCurSel _opforPopList) };
            private _opforLauncherSetting = "Normal";
            if (lbCurSel _launcherList >= 0) then { _opforLauncherSetting = _launcherList lbData (lbCurSel _launcherList) };
            private _opforAirSetting = "Off";
            if (lbCurSel _opforAirList >= 0) then { _opforAirSetting = _opforAirList lbData (lbCurSel _opforAirList) };
            private _operationZoneCount = 6;
            if (lbCurSel _opZonesList >= 0) then { _operationZoneCount = parseNumber (_opZonesList lbData (lbCurSel _opZonesList)) };
            _operationZoneCount = (round _operationZoneCount) max 2 min 10;
            private _timeCompressionScale = 1;
            if (lbCurSel _timeCompressionList >= 0) then { _timeCompressionScale = parseNumber (_timeCompressionList lbData (lbCurSel _timeCompressionList)) };
            private _teleportToPlayerMode = 0;
            if (lbCurSel _tpPlayerModeList >= 0) then { _teleportToPlayerMode = parseNumber (_tpPlayerModeList lbData (lbCurSel _tpPlayerModeList)) };
            private _civiliansEnabled = true;
            if (lbCurSel _civEnabledList >= 0) then { _civiliansEnabled = (_civEnabledList lbData (lbCurSel _civEnabledList)) == "true" };
            private _ctbOnly = false;
            if (lbCurSel _ctbOnlyList >= 0) then { _ctbOnly = (_ctbOnlyList lbData (lbCurSel _ctbOnlyList)) == "true" };

            // Set locally immediately so Loadout/Vehicle GUIs have correct values when opened right after Apply
            missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
            missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
            missionNamespace setVariable ["FADE_scenarioPatrols", _patrolsEnabled];
            missionNamespace setVariable ["FADE_enemySkill", _enemySkill];
            missionNamespace setVariable ["FADE_enemyRouting", _enemyRouting];
            missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
            missionNamespace setVariable ["FADE_opforPopulationSetting", _opforPopulationSetting];
            missionNamespace setVariable ["FADE_opforLauncherSetting", _opforLauncherSetting];
            missionNamespace setVariable ["FADE_opforAirSetting", _opforAirSetting];
            missionNamespace setVariable ["FADE_operationZoneCount", _operationZoneCount];
            missionNamespace setVariable ["FADE_timeCompressionScale", _timeCompressionScale];
            missionNamespace setVariable ["FADE_teleportToPlayerMode", _teleportToPlayerMode];
            missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
            missionNamespace setVariable ["FADE_limitToCtbLoadouts", _ctbOnly];

            private _scenarioApplyArgs = [_hour, _weather, _enemyFaction, _friendlyFaction, _civFaction, _limitGear, _ctbOnly, player, _patrolsEnabled, _enemySkill, _enemyRouting, _enemyAAA, _civiliansEnabled, _aoStrength, _timeCompressionScale, _opforPopulationSetting, _teleportToPlayerMode, _opforLauncherSetting, _opforAirSetting, _operationZoneCount];
            [_scenarioApplyArgs] remoteExec ["FADE_applyScenarioSettings", 2];
            closeDialog 0;
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };
    };
};
