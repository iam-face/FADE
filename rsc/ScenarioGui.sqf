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

FAC_scenarioGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60003;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayScenario") then {
                systemChat "SCENARIO GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _display = findDisplay 60003;
            if (isNull _display) exitWith {};
            uinamespace setVariable ["FAC_scenarioGui_fnc", FAC_scenarioGui_fnc];

            // Time list
            private _timeList = _display displayCtrl 60301;
            lbClear _timeList;
            private _currentHour = missionNamespace getVariable ["FADE_scenarioTime", 12];
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

            // Limit gear to Friendly faction (TRUE / FALSE)
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
            private _currentSkill = missionNamespace getVariable ["FADE_enemySkill", 0.5];
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

            // AO - Strength (Low / Medium / High); used by Area of Operations mission
            private _aoStrengthList = _display displayCtrl 60324;
            lbClear _aoStrengthList;
            { _aoStrengthList lbAdd _x; _aoStrengthList lbSetData [_forEachIndex, _x] } forEach ["Low", "Medium", "High"];
            private _currentAoStrength = missionNamespace getVariable ["FADE_aoStrength", "Medium"];
            private _aoStrengthSel = 1;
            { if (_x == _currentAoStrength) exitWith { _aoStrengthSel = _forEachIndex } } forEach ["Low", "Medium", "High"];
            _aoStrengthList lbSetCurSel _aoStrengthSel;

            // Civilians enabled (governs all ambient civilians)
            private _civEnabledList = _display displayCtrl 60322;
            lbClear _civEnabledList;
            _civEnabledList lbAdd "TRUE";
            _civEnabledList lbSetData [0, "true"];
            _civEnabledList lbAdd "FALSE";
            _civEnabledList lbSetData [1, "false"];
            private _civEnabled = missionNamespace getVariable ["FADE_civiliansEnabled", true];
            _civEnabledList lbSetCurSel (if (_civEnabled) then { 0 } else { 1 });

            // AO: AI JTAC (governs JTAC unit and comms in Area of Operations mission)
            private _aoJtacList = _display displayCtrl 60323;
            lbClear _aoJtacList;
            _aoJtacList lbAdd "TRUE";
            _aoJtacList lbSetData [0, "true"];
            _aoJtacList lbAdd "FALSE";
            _aoJtacList lbSetData [1, "false"];
            private _aoJtacEnabled = missionNamespace getVariable ["FADE_aoJtacEnabled", true];
            _aoJtacList lbSetCurSel (if (_aoJtacEnabled) then { 0 } else { 1 });
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
            private _aoStrengthList = _display displayCtrl 60324;
            private _civEnabledList = _display displayCtrl 60322;
            private _aoJtacList = _display displayCtrl 60323;

            private _hour = 12;
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
            private _enemySkill = 0.5;
            if (lbCurSel _skillList >= 0) then { _enemySkill = parseNumber (_skillList lbData (lbCurSel _skillList)) };
            private _enemyRouting = 0;
            if (lbCurSel _routingList >= 0) then { _enemyRouting = parseNumber (_routingList lbData (lbCurSel _routingList)) };
            private _enemyAAA = "None";
            if (lbCurSel _aaaList >= 0) then { _enemyAAA = _aaaList lbData (lbCurSel _aaaList) };
            private _aoStrength = "Medium";
            if (lbCurSel _aoStrengthList >= 0) then { _aoStrength = _aoStrengthList lbData (lbCurSel _aoStrengthList) };
            private _civiliansEnabled = true;
            if (lbCurSel _civEnabledList >= 0) then { _civiliansEnabled = (_civEnabledList lbData (lbCurSel _civEnabledList)) == "true" };
            private _aoJtacEnabled = true;
            if (lbCurSel _aoJtacList >= 0) then { _aoJtacEnabled = (_aoJtacList lbData (lbCurSel _aoJtacList)) == "true" };

            // Set locally immediately so Loadout/Vehicle GUIs have correct values when opened right after Apply
            missionNamespace setVariable ["FADE_scenarioFriendlyFaction", _friendlyFaction];
            missionNamespace setVariable ["FADE_limitGearToFriendlyFaction", _limitGear];
            missionNamespace setVariable ["FADE_scenarioPatrols", _patrolsEnabled];
            missionNamespace setVariable ["FADE_enemySkill", _enemySkill];
            missionNamespace setVariable ["FADE_enemyRouting", _enemyRouting];
            missionNamespace setVariable ["FADE_enemyAAALevel", _enemyAAA];
            missionNamespace setVariable ["FADE_aoStrength", _aoStrength];
            missionNamespace setVariable ["FADE_civiliansEnabled", _civiliansEnabled];
            missionNamespace setVariable ["FADE_aoJtacEnabled", _aoJtacEnabled];

            [_hour, _weather, _enemyFaction, _friendlyFaction, _civFaction, _limitGear, player, _patrolsEnabled, _enemySkill, _enemyRouting, _enemyAAA, _civiliansEnabled, _aoJtacEnabled, _aoStrength] remoteExec ["FADE_applyScenarioSettings", 2];
            closeDialog 0;
        };
    };
};
