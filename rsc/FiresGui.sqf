// =============================================================================
// FiresGui.sqf - FIRES terminal: spawn / rearm / despawn artillery at logic slots
// =============================================================================
// Server RPCs: FADE_fires_spawnPiece, FADE_fires_despawnSlot, FADE_fires_rearmSlot, FADE_fires_requestState,
//   FADE_firesFoS_droneSpawnRequest, FADE_firesFoS_droneDespawnRequest, FADE_firesFoS_requestSync (initServer)

FAC_firesGui_setDetailsList = {
    params ["_ctrl", ["_text", ""]];
    _ctrl ctrlSetText _text;
};

FAC_firesGui_buildPieceTooltip = {
    params ["_class"];
    if (_class == "") exitWith { "" };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { format ["Class not in CfgVehicles: %1", _class] };
    if (isNil "FAC_vehicleGui_buildVehicleTooltip") exitWith {
        private _dn = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
        if (_dn == "") then { _dn = _class };
        _dn
    };
    [_class] call FAC_vehicleGui_buildVehicleTooltip
};

FAC_firesGui_getAvailableDefs = {
    if (isNil "FAC_fires_artilleryDefinitions") exitWith { [] };
    FAC_fires_artilleryDefinitions select {
        isClass (configFile >> "CfgVehicles" >> (_x select 2))
    }
};

FAC_firesGui_refreshDrillPanel = {
    private _display = findDisplay 60700;
    if (isNull _display) exitWith {};
    private _st = _display displayCtrl 60739;
    if (isNull _st) exitWith {};
    _st ctrlSetText (missionNamespace getVariable ["FAC_fires_drill_activeSummary", ""]);
};

FAC_firesGui_populateDrillCombos = {
    private _display = findDisplay 60700;
    if (isNull _display) exitWith {};
    private _cbT = _display displayCtrl 60733;
    private _cbB = _display displayCtrl 60737;
    if (!isNull _cbT) then {
        lbClear _cbT;
        private _defs = missionNamespace getVariable ["FADE_firesDrillTargetDefinitions", []];
        if (_defs isEqualTo []) then {
            _defs = [["Drill vehicle", "C_Offroad_01_F"]];
        };
        {
            _x params ["_label", "_cls"];
            if (_label == "") then { _label = _cls };
            private _i = _cbT lbAdd _label;
            _cbT lbSetData [_i, _cls];
        } forEach _defs;
        if (lbSize _cbT > 0) then { _cbT lbSetCurSel 0 };
    };
    if (!isNull _cbB) then {
        lbClear _cbB;
        private _i0 = _cbB lbAdd "Along pit direction";
        _cbB lbSetData [_i0, "0"];
        private _i1 = _cbB lbAdd "Random azimuth";
        _cbB lbSetData [_i1, "1"];
        _cbB lbSetCurSel 0;
    };
};

FAC_firesGui_updateDroneStatus = {
    private _display = findDisplay 60700;
    if (isNull _display) exitWith {};
    private _st = _display displayCtrl 60724;
    if (isNull _st) exitWith {};
    private _nid = missionNamespace getVariable ["FAC_firesFoS_rangeDroneNetId", ""];
    private _nm = missionNamespace getVariable ["FAC_firesFoS_droneOwnerName", ""];
    if (_nid == "") then {
        _st ctrlSetText "Drone: inactive — map-click Place; operator gets UAV terminal.";
    } else {
        private _op = if (_nm != "") then { _nm } else { "unknown" };
        _st ctrlSetText format ["Drone: ACTIVE — operator %1 (UAV terminal).", _op];
    };
};

FAC_firesGui_getSlotDisplayName = {
    params ["_slotName"];
    private _names = missionNamespace getVariable ["FADE_firesPosNames", []];
    private _disp = missionNamespace getVariable ["FADE_firesPosDisplayNames", []];
    private _i = _names find _slotName;
    if (_i >= 0 && {count _disp > _i}) exitWith { _disp select _i };
    _slotName
};

// 0 = range (spawn / ammo / preview); 1 = timed drill sub-screen (header tabs, VehicleGui-style).
FAC_firesGui_applyPage = {
    params ["_display", "_page"];
    if (isNull _display) exitWith {};
    missionNamespace setVariable ["FAC_firesGui_page", _page];

    private _d = _display;
    private _move = {
        params ["_idc", "_show", "_pos"];
        private _c = _d displayCtrl _idc;
        if (isNull _c) exitWith {};
        _c ctrlShow _show;
        if (count _pos == 4) then { _c ctrlSetPosition _pos };
        _c ctrlCommit 0;
    };

    private _hide = {
        private _c = _d displayCtrl _this;
        if (isNull _c) exitWith {};
        _c ctrlShow false;
        _c ctrlCommit 0;
    };

    private _tabR = _d displayCtrl 60740;
    private _tabD = _d displayCtrl 60741;
    if (!isNull _tabR && {!isNull _tabD}) then {
        if (_page == 0) then {
            _tabR ctrlSetBackgroundColor [0.22, 0.48, 0.78, 1];
            _tabD ctrlSetBackgroundColor [0.14, 0.16, 0.22, 1];
        } else {
            _tabR ctrlSetBackgroundColor [0.14, 0.16, 0.22, 1];
            _tabD ctrlSetBackgroundColor [0.22, 0.48, 0.78, 1];
        };
        _tabR ctrlCommit 0;
        _tabD ctrlCommit 0;
    };

    if (_page == 0) then {
        { _x call _hide } forEach [60746, 60747, 60748, 60731, 60732, 60733, 60737, 60735, 60736, 60738, 60752];

        [60743, true, [0.04, 0.108, 0.395, 0.022]] call _move;
        [60703, true, [0.04, 0.133, 0.395, 0.34]] call _move;
        [60744, true, [0.04, 0.481, 0.395, 0.022]] call _move;
        [60701, true, [0.04, 0.506, 0.395, 0.285]] call _move;
        [60739, true, [0.04, 0.798, 0.395, 0.036]] call _move;
        [60706, true, [0.04, 0.842, 0.192, 0.046]] call _move;
        [60707, true, [0.243, 0.842, 0.192, 0.046]] call _move;

        [60704, true, [0.455, 0.108, 0.505, 0.24]] call _move;
        [60753, true, [0.455, 0.358, 0.505, 0.022]] call _move;
        [60705, true, [0.455, 0.382, 0.505, 0.056]] call _move;
        [60754, true, [0.455, 0.444, 0.505, 0.022]] call _move;
        [60710, true, [0.455, 0.468, 0.505, 0.225]] call _move;
        [60712, true, [0.455, 0.701, 0.505, 0.022]] call _move;
        [60711, true, [0.455, 0.726, 0.505, 0.026]] call _move;
        [60713, true, [0.455, 0.756, 0.247, 0.038]] call _move;
        [60708, true, [0.713, 0.756, 0.247, 0.038]] call _move;
        [60714, true, [0.455, 0.802, 0.505, 0.042]] call _move;
        [60724, true, [0.455, 0.850, 0.505, 0.028]] call _move;
        [60721, true, [0.455, 0.882, 0.247, 0.034]] call _move;
        [60722, true, [0.713, 0.882, 0.247, 0.034]] call _move;
    } else {
        { _x call _hide } forEach [60743, 60703, 60704, 60753, 60705, 60754, 60710, 60711, 60712, 60713, 60708, 60714, 60724, 60721, 60722, 60706, 60707];

        [60744, true, [0.04, 0.108, 0.44, 0.022]] call _move;
        [60701, true, [0.04, 0.133, 0.44, 0.24]] call _move;

        [60746, true, [0.04, 0.382, 0.44, 0.024]] call _move;
        [60747, true, [0.04, 0.412, 0.09, 0.022]] call _move;
        [60731, true, [0.135, 0.408, 0.11, 0.032]] call _move;
        [60748, true, [0.255, 0.412, 0.09, 0.022]] call _move;
        [60732, true, [0.35, 0.408, 0.11, 0.032]] call _move;
        [60733, true, [0.04, 0.448, 0.44, 0.034]] call _move;

        [60738, true, [0.04, 0.490, 0.44, 0.022]] call _move;
        [60737, true, [0.04, 0.515, 0.44, 0.034]] call _move;

        [60735, true, [0.04, 0.558, 0.205, 0.042]] call _move;
        [60736, true, [0.255, 0.558, 0.205, 0.042]] call _move;

        [60739, true, [0.04, 0.612, 0.92, 0.285]] call _move;

        [60752, true, [0.51, 0.108, 0.455, 0.485]] call _move;
    };
};

FAC_firesGui_updateAmmoPanel = {
    private _display = findDisplay 60700;
    if (isNull _display) exitWith {};
    private _slotLb = _display displayCtrl 60701;
    private _ammoLb = _display displayCtrl 60710;
    private _slider = _display displayCtrl 60711;
    private _label = _display displayCtrl 60712;
    private _apply = _display displayCtrl 60713;

    lbClear _ammoLb;
    _apply ctrlEnable false;
    _slider ctrlEnable false;
    _label ctrlSetText "Total rounds: 0";

    private _is = lbCurSel _slotLb;
    if (_is < 0) exitWith {};
    private _slotName = _slotLb lbData _is;
    private _st = missionNamespace getVariable ["FAC_fires_clientState", []];
    private _iState = _st findIf { (_x select 0) == _slotName };
    if (_iState < 0) exitWith {};
    private _entry = _st select _iState;
    _entry params ["_sn", "_cls", "_ammo", ["_nid", ""], ["_magState", []]];
    if (count _magState == 0) exitWith {};

    {
        _x params [["_mag", ""], ["_cur", 0], ["_max", 1]];
        if !(_mag isEqualType "") then { continue };
        if (_mag == "") then { continue };
        if (_max <= 0) then { _max = 1 };
        if (_cur < 0) then { _cur = 0 };
        if (_cur > _max) then { _cur = _max };
        private _cfg = configFile >> "CfgMagazines" >> _mag;
        private _dn = if (isClass _cfg) then { getText (_cfg >> "displayName") } else { "" };
        if (_dn == "") then { _dn = _mag };
        private _row = _ammoLb lbAdd format ["%1 (%2) — total %3 / %4", _dn, _mag, _cur, _max];
        _ammoLb lbSetData [_row, str [_mag, _cur, _max]];
    } forEach _magState;

    if (lbSize _ammoLb > 0) then {
        _ammoLb lbSetCurSel 0;
        _apply ctrlEnable true;
        _slider ctrlEnable true;
        ["ammoSelChanged", []] call FAC_firesGui_fnc;
    };
};

FAC_firesGui_fnc = {
    params ["_action", "_params"];

    switch _action do {
        case "open": {
            if (!createDialog "RscDisplayFires") then {
                systemChat "FIRES GUI: RESOURCE NOT FOUND.";
            };
        };

        case "onLoad": {
            uinamespace setVariable ["FAC_firesGui_fnc", FAC_firesGui_fnc];
            missionNamespace setVariable ["FAC_firesGui_lastStateSig", ""];
            [player] remoteExec ["FADE_fires_requestState", 2];
            [player] remoteExec ["FADE_firesFoS_requestSync", 2];
            [player] remoteExec ["FADE_fires_drillRequestSummary", 2];
            ["refreshUi", [true]] call FAC_firesGui_fnc;
            call FAC_firesGui_populateDrillCombos;
            call FAC_firesGui_refreshDrillPanel;
            call FAC_firesGui_updateDroneStatus;
        };

        case "headerRefresh": {
            [player] remoteExec ["FADE_fires_requestState", 2];
            [player] remoteExec ["FADE_firesFoS_requestSync", 2];
            [player] remoteExec ["FADE_fires_drillRequestSummary", 2];
            [] spawn {
                sleep 0.35;
                if (!isNull (findDisplay 60700)) then {
                    private _pg = missionNamespace getVariable ["FAC_firesGui_page", 0];
                    ["refreshUi", [true]] call FAC_firesGui_fnc;
                    call FAC_firesGui_refreshDrillPanel;
                    call FAC_firesGui_updateDroneStatus;
                    ["setPage", [_pg]] call FAC_firesGui_fnc;
                };
            };
        };

        case "setPage": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _p = _params param [0, 0];
            [_display, _p] call FAC_firesGui_applyPage;
        };

        case "refreshUi": {
            private _force = _params param [0, false];
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};

            private _pieceLb = _display displayCtrl 60703;
            private _slotLb = _display displayCtrl 60701;
            private _avail = [] call FAC_firesGui_getAvailableDefs;
            private _st = missionNamespace getVariable ["FAC_fires_clientState", []];
            private _sig = str _st;
            private _lastSig = missionNamespace getVariable ["FAC_firesGui_lastStateSig", ""];
            if (!_force && {_sig == _lastSig}) exitWith {
                // Keep ammo panel responsive without rebuilding/scroll-jumping lists.
                call FAC_firesGui_updateAmmoPanel;
            };
            missionNamespace setVariable ["FAC_firesGui_lastStateSig", _sig];

            private _prevPiece = if (lbCurSel _pieceLb >= 0) then { _pieceLb lbData (lbCurSel _pieceLb) } else { "" };
            private _prevSlot = if (lbCurSel _slotLb >= 0) then { _slotLb lbData (lbCurSel _slotLb) } else { "" };
            lbClear _pieceLb;
            {
                _x params ["_cat", "_label", "_cls"];
                private _type = _cat;
                if (_type == "") then { _type = _cls };
                private _dn = getText (configFile >> "CfgVehicles" >> _cls >> "displayName");
                if (_dn == "") then { _dn = _cls };
                private _show = if (_label != "") then { _label } else { _dn };
                private _row = _pieceLb lbAdd format ["%1 > %2", _type, _show];
                _pieceLb lbSetData [_row, _cls];
                private _tip = [_cls] call FAC_firesGui_buildPieceTooltip;
                _pieceLb lbSetTooltip [_row, if (_tip != "") then { _tip } else { _cls }];
            } forEach _avail;
            private _psel = 0;
            if (_prevPiece != "") then {
                for "_k" from 0 to (lbSize _pieceLb - 1) do {
                    if ((_pieceLb lbData _k) == _prevPiece) exitWith { _psel = _k };
                };
            };
            if (lbSize _pieceLb > 0) then { _pieceLb lbSetCurSel _psel };

            lbClear _slotLb;
            {
                _x params ["_slotName", "_cls", "_ammo", ["_nid", ""]];
                private _slotDisp = [_slotName] call FAC_firesGui_getSlotDisplayName;
                private _logicOk = !isNull (missionNamespace getVariable [_slotName, objNull]);
                private _line = if (_cls == "") then {
                    format ["%1 — empty%2", _slotDisp, if (!_logicOk) then { " (no Eden logic)" } else { "" }]
                } else {
                    private _dn = if (isClass (configFile >> "CfgVehicles" >> _cls)) then {
                        getText (configFile >> "CfgVehicles" >> _cls >> "displayName")
                    } else {
                        _cls
                    };
                    if (_dn == "") then { _dn = _cls };
                    format ["%1 — %2 | ammo ~%3 rds", _slotDisp, _dn, _ammo]
                };
                private _i = _slotLb lbAdd _line;
                _slotLb lbSetData [_i, _slotName];
            } forEach _st;
            private _ssel = 0;
            if (_prevSlot != "") then {
                for "_k" from 0 to (lbSize _slotLb - 1) do {
                    if ((_slotLb lbData _k) == _prevSlot) exitWith { _ssel = _k };
                };
            };
            if (lbSize _slotLb > 0) then { _slotLb lbSetCurSel _ssel };

            ["selChanged", []] call FAC_firesGui_fnc;
            call FAC_firesGui_updateAmmoPanel;
            call FAC_firesGui_refreshDrillPanel;
            call FAC_firesGui_updateDroneStatus;
            [_display, missionNamespace getVariable ["FAC_firesGui_page", 0]] call FAC_firesGui_applyPage;
        };

        case "selChanged": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _pic = _display displayCtrl 60704;
            private _det = _display displayCtrl 60705;
            private _pieceLb = _display displayCtrl 60703;
            private _idx = lbCurSel _pieceLb;
            if (_idx < 0) exitWith {
                if ((missionNamespace getVariable ["FAC_firesGui_page", 0]) == 1) exitWith {};
                _pic ctrlSetText "";
                [_det, ""] call FAC_firesGui_setDetailsList;
            };
            private _cls = _pieceLb lbData _idx;
            if (!isClass (configFile >> "CfgVehicles" >> _cls)) exitWith {
                _pic ctrlSetText "";
                [_det, "Invalid class."] call FAC_firesGui_setDetailsList;
            };
            private _cfgVeh = configFile >> "CfgVehicles" >> _cls;
            private _texture = getText (_cfgVeh >> "editorPreview");
            if (_texture == "") then { _texture = getText (_cfgVeh >> "picture") };
            if (_texture == "") then { _texture = getText (_cfgVeh >> "icon") };
            if (_texture != "") then { _pic ctrlSetText _texture } else { _pic ctrlSetText "" };
            private _dn = getText (_cfgVeh >> "displayName");
            if (_dn == "") then { _dn = _cls };
            [_det, format ["%1 (%2)", _dn, _cls]] call FAC_firesGui_setDetailsList;
            call FAC_firesGui_updateAmmoPanel;
        };

        case "slotSelChanged": {
            call FAC_firesGui_updateAmmoPanel;
        };

        case "ammoSelChanged": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _ammoLb = _display displayCtrl 60710;
            private _slider = _display displayCtrl 60711;
            private _idx = lbCurSel _ammoLb;
            if (_idx >= 0) then {
                private _trip = call compile (_ammoLb lbData _idx);
                private _cur = _trip param [1, 0];
                private _max = _trip param [2, 1];
                if (_max <= 0) then { _max = 1 };
                if (_cur < 0) then { _cur = 0 };
                if (_cur > _max) then { _cur = _max };
                _slider sliderSetRange [0, _max];
                _slider sliderSetSpeed [1, 1];
                _slider sliderSetPosition _cur;
            };
            ["ammoSliderChanged", []] call FAC_firesGui_fnc;
        };

        case "ammoSliderChanged": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _ammoLb = _display displayCtrl 60710;
            private _slider = _display displayCtrl 60711;
            private _label = _display displayCtrl 60712;
            private _idx = lbCurSel _ammoLb;
            if (_idx < 0) exitWith { _label ctrlSetText "Total rounds: 0" };
            private _data = _ammoLb lbData _idx;
            private _trip = call compile _data;
            private _max = _trip param [2, 1];
            private _cur = _trip param [1, 0];
            if (_max <= 0) then { _max = 1 };
            _slider sliderSetRange [0, _max];
            _slider sliderSetSpeed [1, 1];
            private _pos = round (sliderPosition _slider);
            if (_pos > _max) then {
                _pos = _max;
                _slider sliderSetPosition _pos;
            };
            _label ctrlSetText format ["Total rounds: %1 / %2", _pos, _max];
        };

        case "ammoApply": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _ammoLb = _display displayCtrl 60710;
            private _is = lbCurSel _slotLb;
            private _ia = lbCurSel _ammoLb;
            if (_is < 0) exitWith { systemChat "Select a range slot."; };
            if (_ia < 0) exitWith { systemChat "Select an ammo type."; };
            private _slotName = _slotLb lbData _is;
            private _trip = call compile (_ammoLb lbData _ia);
            private _mag = _trip param [0, ""];
            private _max = _trip param [2, 1];
            if (_max <= 0) then { _max = 1 };
            private _slider = _display displayCtrl 60711;
            private _rounds = round (sliderPosition _slider);
            if (_rounds < 0) then { _rounds = 0 };
            if (_rounds > _max) then { _rounds = _max };
            [_slotName, _mag, _rounds, player] remoteExec ["FADE_fires_setAmmoAmount", 2];
            systemChat "FIRES: ammo load update requested.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "spawn": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _pieceLb = _display displayCtrl 60703;
            private _is = lbCurSel _slotLb;
            private _ip = lbCurSel _pieceLb;
            if (_is < 0) exitWith { systemChat "Select a range slot." };
            if (_ip < 0) exitWith { systemChat "Select an artillery piece." };
            private _slotName = _slotLb lbData _is;
            private _cls = _pieceLb lbData _ip;
            [_slotName, _cls, player] remoteExec ["FADE_fires_spawnPiece", 2];
            systemChat "FIRES: spawn requested.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "despawn": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _is = lbCurSel _slotLb;
            if (_is < 0) exitWith { systemChat "Select a range slot." };
            private _slotName = _slotLb lbData _is;
            [_slotName, player] remoteExec ["FADE_fires_despawnSlot", 2];
            systemChat "FIRES: despawn requested.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "rearm": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _is = lbCurSel _slotLb;
            if (_is < 0) exitWith { systemChat "Select a range slot." };
            private _slotName = _slotLb lbData _is;
            [_slotName, player] remoteExec ["FADE_fires_rearmSlot", 2];
            systemChat "FIRES: rearm requested.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "spawnAmmoTruck": {
            [player] remoteExec ["FADE_fires_spawnAmmoTruck", 2];
            systemChat "FIRES: ammo truck spawn requested.";
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "droneMapPlace": {
            closeDialog 0;
            [] spawn {
                sleep 0.15;
                if (!hasInterface) exitWith {};
                [] call FAC_firesFoS_fnc_startMapClickDrone;
            };
            systemChat "FIRES: map opening — click where the observer drone should hover.";
        };

        case "droneDespawn": {
            [player] remoteExec ["FADE_firesFoS_droneDespawnRequest", 2];
            systemChat "FIRES: observer drone despawn requested.";
            [] spawn {
                sleep 0.5;
                if (!isNull (findDisplay 60700)) then { call FAC_firesGui_updateDroneStatus };
            };
        };

        case "drillStart": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _is = lbCurSel _slotLb;
            if (_is < 0) exitWith { systemChat "FIRES drill: select a slot first."; };
            private _slotName = _slotLb lbData _is;
            private _minT = ctrlText (_display displayCtrl 60731);
            private _maxT = ctrlText (_display displayCtrl 60732);
            private _ti = lbCurSel (_display displayCtrl 60733);
            if (_ti < 0) then { _ti = 0 };
            private _bi = lbCurSel (_display displayCtrl 60737);
            if (_bi < 0) then { _bi = 0 };
            [_slotName, _minT, _maxT, _ti, _bi, player] remoteExec ["FADE_fires_drillStart", 2];
            systemChat "FIRES drill: start requested.";
            [] spawn {
                sleep 0.4;
                if (!isNull (findDisplay 60700)) then {
                    [player] remoteExec ["FADE_fires_drillRequestSummary", 2];
                    sleep 0.15;
                    call FAC_firesGui_refreshDrillPanel;
                };
            };
        };

        case "drillEnd": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _slotLb = _display displayCtrl 60701;
            private _is = lbCurSel _slotLb;
            if (_is < 0) exitWith { systemChat "FIRES drill: select a slot to end its drill."; };
            private _slotName = _slotLb lbData _is;
            [_slotName, player] remoteExec ["FADE_fires_drillCancel", 2];
            [] spawn {
                sleep 0.35;
                if (!isNull (findDisplay 60700)) then {
                    [player] remoteExec ["FADE_fires_drillRequestSummary", 2];
                    sleep 0.15;
                    call FAC_firesGui_refreshDrillPanel;
                };
            };
        };
    };
};
