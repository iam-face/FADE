// ServerWorldWeather.sqf - weather, time compression, initial apply
// -----------------------------------------------------------------------------
// Weather: numeric params [overcast, rain, fogD, fogDecay, fogBase, windStr, windDir, gusts, waves]
// Preset names map to the same values the legacy switch used. Call only on server.
// -----------------------------------------------------------------------------
FADE_getWeatherParamsForPresetName = {
    params ["_name"];
    switch _name do {
        case "Clear": { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Overcast": { [0.5, 0, 0, 0, 0, 0, 0, 0, 0] };
        case "Foggy": { [0.3, 0, 0.5, 0.01, 0, 0, 0, 0, 0] };
        case "Rain": { [0.8, 0.5, 0.1, 0.01, 0, 0, 0, 0, 0] };
        case "Storm": { [1, 1, 0.2, 0.01, 0, 0, 0, 0, 0] };
        case "FaceMission": { [1, 1, 0.5, 0.01, 0, 0, 0, 0, 0] };
        default { [0, 0, 0, 0, 0, 0, 0, 0, 0] };
    };
};

FADE_applyWeatherFromParams = {
    params ["_a"];
    if (!(_a isEqualType []) || { count _a < 9 }) exitWith {};
    _a params ["_oc", "_rn", "_fd", "_fde", "_fb", "_wS", "_wD", "_gs", "_wv"];
    0 setOvercast ((_oc max 0) min 1);
    0 setRain ((_rn max 0) min 1);
    0 setFog [((_fd max 0) min 1), ((_fde max 0) min 1), (_fb max 0) min 500];
    0 setWindStr ((_wS max 0) min 1);
    0 setWindDir (_wD % 360);
    0 setGusts ((_gs max 0) min 1);
    0 setWaves ((_wv max 0) min 1);
    forceWeatherChange;
};

FADE_applyWeatherPreset = {
    params ["_preset"];
    private _p = [_preset] call FADE_getWeatherParamsForPresetName;
    [_p] call FADE_applyWeatherFromParams;
};

// -----------------------------------------------------------------------------
// Pseudo time compression (server): exact real-time scaling with skipTime.
// IMPORTANT: no 'sleep' here (sleep is simulation-time and can cause runaway).
// Target: 100x means 100 mission-seconds per 1 real second.
// We keep engine 1x and add only extra: (scale - 1) * realDelta.
// -----------------------------------------------------------------------------
FADE_timeCompressionPollSec = 1;
[] spawn {
    private _lastTick = diag_tickTime;
    private _nextTick = _lastTick + FADE_timeCompressionPollSec;
    while { true } do {
        waitUntil { diag_tickTime >= _nextTick };
        private _now = diag_tickTime;
        private _realDelta = _now - _lastTick;
        _lastTick = _now;
        _nextTick = _now + FADE_timeCompressionPollSec;
        if (_realDelta <= 0) then { continue };

        private _scale = missionNamespace getVariable ["FADE_timeCompressionScale", 1];
        _scale = (_scale max 1) min 100;
        if (_scale <= 1) then { continue };

        // skipTime expects hours
        private _extraHours = ((_scale - 1) * _realDelta) / 3600;
        if (_extraHours > 0) then { skipTime _extraHours };
    };
};

// Apply initial time and weather from Config (server; syncs to clients)
private _initHour = missionNamespace getVariable ["FADE_scenarioTime", 18];
private _initWeather = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
private _initWp = missionNamespace getVariable ["FADE_scenarioWeatherParams", []];
private _date = date;
setDate [_date select 0, _date select 1, _date select 2, _initHour, _date select 4];
if ((count _initWp) >= 9) then {
    [_initWp] call FADE_applyWeatherFromParams;
} else {
    [_initWeather] call FADE_applyWeatherPreset;
};
