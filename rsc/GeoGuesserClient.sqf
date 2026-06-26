// =============================================================================
// GeoGuesserClient.sqf  -  map guess UI + reveal (client)
// =============================================================================
if (!hasInterface) exitWith {};

FADE_ggClient_closeMissionGui = {
    if (!hasInterface) exitWith {};
    if (!isNil "FAC_geoGuesserPickGui_fnc_destroyOverlay") then { [] call FAC_geoGuesserPickGui_fnc_destroyOverlay };
    if (!isNil "FAC_escapeEvasionPickGui_fnc_destroyOverlay") then { [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay };
    if (!isNil "FAC_missionPickOverlay_destroy") then {
        ["FAC_ggPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
        ["FAC_eePick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };
    if (!isNull (findDisplay 60002)) then { closeDialog 0 };
};

FADE_ggClient_hintBuilder = {
    params ["_rem"];
    private _total = missionNamespace getVariable ["FADE_ggClient_timeSec", 60];
    if (_rem < 0) then {
        format [
            "GEO-GUESSER%1Look around, then open your map (M) and click where you think you are.%1You have %2 seconds.",
            toString [10, 10],
            _total
        ]
    } else {
        format [
            "GEO-GUESSER%1Open map (M) and click your guess when ready.%1%2 s remaining.",
            toString [10, 10],
            _rem
        ]
    };
};

FADE_ggClient_onGuessTimeout = {
    missionNamespace setVariable ["FADE_ggClient_mapActive", false];
};

FADE_ggClient_onGuessClick = {
    params ["_clickPos"];
    private _taskId = missionNamespace getVariable ["FADE_ggClient_taskId", ""];
    if (_taskId == "") exitWith {};
    if !(missionNamespace getVariable ["FADE_ggClient_active", false]) exitWith {};
    missionNamespace setVariable ["FADE_ggClient_active", false];
    [_taskId, _clickPos, player] remoteExec ["FADE_geoGuesser_submitGuess", 2];
    hint parseText "<t color='#A0D0A0'>Guess recorded.</t><br/><t color='#808080'>Returning to base. Results when the round ends.</t>";
};

FADE_ggClient_forceStop = {
    missionNamespace setVariable ["FADE_ggClient_active", false];
    missionNamespace setVariable ["FADE_ggClient_taskId", nil];
    if (missionNamespace getVariable ["FADE_ggClient_mapActive", false]) then {
        ["FADE_ggClient_mapActive", FADE_ggClient_onGuessTimeout, false] call FADE_mapClickPick_finish;
    };
};

FADE_ggClient_beginRound = {
    params ["_taskId", "_timeSec", "_difficulty", "_deadlineServerTime"];
    if (!hasInterface) exitWith {};
    [] call FADE_ggClient_closeMissionGui;
    [] call FADE_ggClient_forceStop;
    if (visibleMap) then { openMap false };
    missionNamespace setVariable ["FADE_ggClient_taskId", _taskId];
    missionNamespace setVariable ["FADE_ggClient_timeSec", _timeSec];
    missionNamespace setVariable ["FADE_ggClient_active", true];
    if (_difficulty in ["Hard", "Impossible"]) then {
        private _strip = missionNamespace getVariable ["FADE_clientStripEvadeeGPS", {}];
        if (_strip isEqualType {}) then {
            [] call _strip;
        } else {
            if ("ItemGPS" in assignedItems player) then { player unlinkItem "ItemGPS" };
            player removeItem "ItemGPS";
        };
    };
    private _rem = ((_deadlineServerTime - serverTime) max 0) + 1;
    [
        "FADE_ggClient_mapActive",
        "FADE_ggClient_mapEh",
        _rem,
        FADE_ggClient_hintBuilder,
        FADE_ggClient_onGuessClick,
        FADE_ggClient_onGuessTimeout,
        true,
        false
    ] call FADE_mapClickPick_start;
};

FADE_ggClient_showResults = {
    params ["_html", "_revealRows"];
    if (!hasInterface) exitWith {};
    [] call FADE_ggClient_forceStop;
    [_html] call FADE_showMissionHint;
    if !(_revealRows isEqualType []) then { _revealRows = [] };
    private _markers = [];
    {
        _x params ["_pName", "_actual", "_guess", ["_uid", ""]];
        if !(_pName isEqualType "") then { continue };
        private _tag = if (_uid isEqualType "" && { _uid != "" }) then { _uid } else { _pName };
        if (_actual isEqualType [] && { count _actual >= 2 }) then {
            private _mLoc = format ["FAC_ggRevL_%1_%2", _tag, floor random 99999];
            createMarkerLocal [_mLoc, _actual];
            _mLoc setMarkerTypeLocal "mil_dot";
            _mLoc setMarkerColorLocal "ColorGreen";
            _mLoc setMarkerTextLocal (format ["%1's Location", _pName]);
            _markers pushBack _mLoc;
        };
        if (_guess isEqualType [] && { count _guess >= 2 }) then {
            private _mGuess = format ["FAC_ggRevG_%1_%2", _tag, floor random 99999];
            createMarkerLocal [_mGuess, _guess];
            _mGuess setMarkerTypeLocal "mil_dot";
            _mGuess setMarkerColorLocal "ColorOrange";
            _mGuess setMarkerTextLocal (format ["%1's Guess", _pName]);
            _markers pushBack _mGuess;
        };
    } forEach _revealRows;
    if (count _markers > 0) then {
        [_markers] spawn {
            params ["_mkrs"];
            sleep 30;
            { deleteMarkerLocal _x } forEach _mkrs;
        };
    };
};

missionNamespace setVariable ["FADE_ggClient_hintBuilder", FADE_ggClient_hintBuilder];
missionNamespace setVariable ["FADE_ggClient_closeMissionGui", FADE_ggClient_closeMissionGui];
missionNamespace setVariable ["FADE_ggClient_beginRound", FADE_ggClient_beginRound];
missionNamespace setVariable ["FADE_ggClient_forceStop", FADE_ggClient_forceStop];
missionNamespace setVariable ["FADE_ggClient_showResults", FADE_ggClient_showResults];
