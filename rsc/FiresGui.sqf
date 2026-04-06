// =============================================================================
// FiresGui.sqf - FIRES terminal: spawn / rearm / despawn artillery at logic slots
// =============================================================================
// Server RPCs: FADE_fires_spawnPiece, FADE_fires_despawnSlot, FADE_fires_rearmSlot, FADE_fires_requestState (initServer)

FAC_firesGui_setDetailsList = {
    params ["_ctrl", ["_text", ""]];
    _ctrl ctrlSetText _text;
};

FAC_firesGui_buildPieceTooltip = {
    params ["_class"];
    if (_class == "") exitWith { "" };
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith { format ["Class not in CfgVehicles: %1", _class] };
    [_class] call FAC_vehicleGui_buildVehicleTooltip
};

FAC_firesGui_getAvailableDefs = {
    if (isNil "FAC_fires_artilleryDefinitions") exitWith { [] };
    FAC_fires_artilleryDefinitions select {
        isClass (configFile >> "CfgVehicles" >> (_x select 2))
    }
};

FAC_firesGui_getSlotDisplayName = {
    params ["_slotName"];
    private _names = missionNamespace getVariable ["FADE_firesPosNames", []];
    private _disp = missionNamespace getVariable ["FADE_firesPosDisplayNames", []];
    private _i = _names find _slotName;
    if (_i >= 0 && {count _disp > _i}) exitWith { _disp select _i };
    _slotName
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
            ["refreshUi", [true]] call FAC_firesGui_fnc;
        };

        case "headerRefresh": {
            [player] remoteExec ["FADE_fires_requestState", 2];
            [] spawn {
                sleep 0.35;
                if (!isNull (findDisplay 60700)) then {
                    ["refreshUi", [true]] call FAC_firesGui_fnc;
                };
            };
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
                private _row = _pieceLb lbAdd format ["%1 > %2", _type, _dn];
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
        };

        case "selChanged": {
            private _display = findDisplay 60700;
            if (isNull _display) exitWith {};
            private _pic = _display displayCtrl 60704;
            private _det = _display displayCtrl 60705;
            private _pieceLb = _display displayCtrl 60703;
            private _idx = lbCurSel _pieceLb;
            if (_idx < 0) exitWith {
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
    };
};
