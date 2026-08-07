// =============================================================================
// PointDefensePickGui.sqf  -  duration slider + Random / Map-click (60002 overlay)
// =============================================================================
if (hasInterface) then {
    FAC_pointDefensePickGui_fnc_destroyOverlay = {
        if (isNil "FAC_missionPickOverlay_destroy") exitWith {};
        ["FAC_pdPick_overlayCtrls"] call FAC_missionPickOverlay_destroy;
    };

    FAC_pointDefensePickGui_fnc_readDurationSec = {
        private _display = findDisplay 60002;
        private _minS = missionNamespace getVariable ["FADE_pointDefenseDurationMinSec", 300];
        private _maxS = missionNamespace getVariable ["FADE_pointDefenseDurationMaxSec", 2400];
        private _defS = missionNamespace getVariable ["FADE_pointDefenseDurationSec", 1200];
        private _sec = _defS;
        if (!isNull _display) then {
            private _sl = _display displayCtrl 60372;
            if (!isNull _sl) then { _sec = round (sliderPosition _sl) };
        };
        (_sec max _minS) min _maxS
    };

    FAC_pointDefensePickGui_fnc_formatDuration = {
        params ["_sec"];
        private _m = floor (_sec / 60);
        private _s = round (_sec - (_m * 60));
        if (_s <= 0) then {
            format ["%1 min", _m]
        } else {
            format ["%1 min %2 s", _m, _s]
        }
    };

    FAC_pointDefensePickGui_fnc = {
        params ["_action", ["_params", []]];
        private _display = findDisplay 60002;
        switch _action do {
            case "open": {
                if (isNull _display) exitWith {
                    systemChat "POINT DEFENSE: open Manage Missions first, then start this mission type.";
                };
                if (isNil "FAC_missionPickOverlay_createShell") exitWith {
                    systemChat "POINT DEFENSE: location overlay not loaded.";
                };
                disableSerialization;
                [] call FAC_pointDefensePickGui_fnc_destroyOverlay;
                if (!isNil "FAC_missionPickOverlay_setBaseVisible") then {
                    [false] call FAC_missionPickOverlay_setBaseVisible;
                };
                private _minS = missionNamespace getVariable ["FADE_pointDefenseDurationMinSec", 300];
                private _maxS = missionNamespace getVariable ["FADE_pointDefenseDurationMaxSec", 2400];
                private _defS = missionNamespace getVariable ["FADE_pointDefenseDurationSec", 1200];
                _defS = (_defS max _minS) min _maxS;
                private _timeout = missionNamespace getVariable ["FADE_missionMapPickTimeoutSec", 20];
                private _helpText = format [
                    "Hold a 250 m zone against enemy assault waves. Timer starts when players enter the zone.%1Random: snaps to a civilian settlement zone.%1Map click: uses your click (no civ-zone snap; %2 s limit).%1%1Set defend duration, then choose location.",
                    toString [10],
                    _timeout
                ];
                private _padX = 0.04;
                private _bgW = 0.64;
                private _bgX = 0.18;
                private _titleH = 0.046;
                private _innerW = _bgW - (_padX * 2);
                private _helpH = 0.16;
                if (!isNil "FAC_missionPickOverlay_estimateHelpH") then {
                    _helpH = [_helpText, _innerW] call FAC_missionPickOverlay_estimateHelpH;
                };
                if (!(_helpH isEqualType 0)) then { _helpH = 0.16 };
                private _sliderBlock = 0.09;
                private _btnH = 0.052;
                private _btnGap = 0.012;
                private _btnBlock = (_btnH * 3) + (_btnGap * 2) + 0.028;
                private _bgH = _titleH + 0.012 + _helpH + _sliderBlock + _btnBlock + 0.016;
                private _bgY = ((1 - _bgH) / 2) max 0.06;
                private _layout = [_bgX, _bgY, _bgW, _bgH, _titleH, _helpH];
                private _controls = [_display, "POINT DEFENSE - SETUP", _helpText, 60360, _layout] call FAC_missionPickOverlay_createShell;
                private _innerX = _bgX + _padX;
                private _sliderY = _bgY + _titleH + _helpH + 0.01;

                private _durLbl = _display ctrlCreate ["RscText", 60370];
                _durLbl ctrlSetPosition [_innerX, _sliderY, _innerW * 0.45, 0.026];
                _durLbl ctrlSetText "Defend duration";
                _durLbl ctrlCommit 0;
                _controls pushBack _durLbl;

                private _durVal = _display ctrlCreate ["RscText", 60371];
                _durVal ctrlSetPosition [_innerX + (_innerW * 0.45), _sliderY, _innerW * 0.55, 0.026];
                _durVal ctrlSetText ([_defS] call FAC_pointDefensePickGui_fnc_formatDuration);
                _durVal ctrlSetTextColor [0.75, 0.78, 0.82, 1];
                _durVal ctrlCommit 0;
                _controls pushBack _durVal;

                private _durSl = _display ctrlCreate ["RscXSliderH", 60372];
                _durSl ctrlSetPosition [_innerX, _sliderY + 0.03, _innerW, 0.032];
                _durSl sliderSetRange [_minS, _maxS];
                _durSl sliderSetSpeed [60, 60];
                _durSl sliderSetPosition _defS;
                _durSl ctrlAddEventHandler ["SliderPosChanged", {
                    ["durationSlider", []] call (missionNamespace getVariable ["FAC_pointDefensePickGui_fnc", {}]);
                }];
                _durSl ctrlCommit 0;
                _controls pushBack _durSl;

                private _btnY = _sliderY + _sliderBlock + 0.008;
                private _bRandom = _display ctrlCreate ["RscButton", 60373];
                _bRandom ctrlSetPosition [_innerX, _btnY, _innerW, _btnH];
                _bRandom ctrlSetText "Random location";
                [_bRandom] call FAC_missionPick_stylePrimary;
                _bRandom ctrlCommit 0;
                _bRandom ctrlAddEventHandler ["ButtonClick", { ["random", []] call (missionNamespace getVariable ["FAC_pointDefensePickGui_fnc", {}]) }];
                _controls pushBack _bRandom;

                private _bMap = _display ctrlCreate ["RscButton", 60374];
                _bMap ctrlSetPosition [_innerX, _btnY + _btnH + _btnGap, _innerW, _btnH];
                _bMap ctrlSetText "Map click (choose area on map)";
                [_bMap] call FAC_missionPick_styleStart;
                _bMap ctrlCommit 0;
                _bMap ctrlAddEventHandler ["ButtonClick", { ["mapClick", []] call (missionNamespace getVariable ["FAC_pointDefensePickGui_fnc", {}]) }];
                _controls pushBack _bMap;

                private _bCancel = _display ctrlCreate ["RscButton", 60375];
                _bCancel ctrlSetPosition [_innerX, _btnY + (_btnH + _btnGap) * 2, _innerW, _btnH];
                _bCancel ctrlSetText "Cancel";
                [_bCancel] call FAC_missionPick_styleDanger;
                _bCancel ctrlCommit 0;
                _bCancel ctrlAddEventHandler ["ButtonClick", { ["cancel", []] call (missionNamespace getVariable ["FAC_pointDefensePickGui_fnc", {}]) }];
                _controls pushBack _bCancel;

                uinamespace setVariable ["FAC_pdPick_overlayCtrls", _controls];
                uinamespace setVariable ["FAC_pdPick_durationSec", _defS];
            };
            case "durationSlider": {
                disableSerialization;
                _display = findDisplay 60002;
                if (isNull _display) exitWith {};
                private _sl = _display displayCtrl 60372;
                private _tv = _display displayCtrl 60371;
                if (isNull _sl || { isNull _tv }) exitWith {};
                private _sec = [] call FAC_pointDefensePickGui_fnc_readDurationSec;
                _sl sliderSetPosition _sec;
                _tv ctrlSetText ([_sec] call FAC_pointDefensePickGui_fnc_formatDuration);
                uinamespace setVariable ["FAC_pdPick_durationSec", _sec];
            };
            case "random": {
                private _sec = [] call FAC_pointDefensePickGui_fnc_readDurationSec;
                [] call FAC_pointDefensePickGui_fnc_destroyOverlay;
                [player, [], _sec] remoteExec ["FADE_startPointDefense", 2];
                hint parseText "<t size='1.1' color='#A0D0A0'>Loading Point Defense...</t><br/><t color='#808080'>Details will be provided shortly.</t>";
                missionNamespace setVariable ["FAC_missionsGui_tab", "active"];
                [] call FAC_missionsGui_syncTabs;
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
            case "mapClick": {
                private _sec = [] call FAC_pointDefensePickGui_fnc_readDurationSec;
                uinamespace setVariable ["FAC_pdPick_durationSec", _sec];
                missionNamespace setVariable ["FAC_pdPick_durationSec", _sec];
                [] call FAC_pointDefensePickGui_fnc_destroyOverlay;
                private _missionsDisp = findDisplay 60002;
                if (!isNull _missionsDisp) then { closeDialog 60002 };
                missionNamespace setVariable ["FAC_missionMapPick_execType", "PointDefense"];
                [] spawn {
                    sleep 0.15;
                    execVM "rsc\MissionMapPick_exec.sqf";
                };
            };
            case "cancel": {
                [] call FAC_pointDefensePickGui_fnc_destroyOverlay;
            };
            default { };
        };
    };
    missionNamespace setVariable ["FAC_pointDefensePickGui_fnc", FAC_pointDefensePickGui_fnc];
};
