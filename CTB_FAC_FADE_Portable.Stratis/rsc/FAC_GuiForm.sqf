// =============================================================================
// FAC_GuiForm.sqf — one terminal shell, filled from a spec.
// Classes (FACRsc*) are the look. A menu passes rows; this file places them.
// ctrlCreate: https://community.bistudio.com/wiki/ctrlCreate
//   display ctrlCreate [class, idc, controlsGroup] — third arg optional, 1.70+
// ctrlAddEventHandler: https://community.bistudio.com/wiki/ctrlAddEventHandler
//   Drop the "on" prefix. _this is the event args.
// ctrlSetPosition + ctrlCommit 0 move a control. Inside a controls group, x/y
// are relative to that group.
// =============================================================================

FAC_GUI_GAP = 0.010;
FAC_GUI_LABEL_H = 0.034;
FAC_GUI_HINT_H = 0.032;
FAC_GUI_BTN_H = 0.042;
FAC_GUI_INPUT_H = 0.040;
FAC_GUI_SLIDER_H = 0.030;
FAC_GUI_SECTION_H = 0.036;
FAC_GUI_PAD = 0.006;

// One line at FAC_GUI_HINT_H, plus a little pad so the structured-text line is not clipped.
// Char width is conservative so a long sentence gets a second line instead of running out of the box.
FAC_gui_hintH = {
    params ["_hint", "_width"];
    if (_hint isEqualTo "") exitWith { 0 };
    private _chars = floor (_width / 0.0125);
    if (_chars < 18) then { _chars = 18 };
    private _lines = ceil ((count _hint) / _chars);
    if (_lines < 1) then { _lines = 1 };
    if (_lines > 4) then { _lines = 4 };
    (FAC_GUI_HINT_H * _lines) + 0.008
};

// Editor preview images are 16:9. pixelW / pixelH are one pixel in GUI units, so the
// control matches that ratio on the current resolution instead of stretching.
// https://community.bistudio.com/wiki/pixelW
// https://community.bistudio.com/wiki/pixelH
FAC_gui_pictureSize = {
    params ["_row", "_maxW"];
    private _aspect = _row param [3, 1.778];
    private _maxH = _row param [4, 0.34];
    if !(_aspect isEqualType 0) then { _aspect = 1.778 };
    if (_aspect < 0.2) then { _aspect = 1.778 };
    if !(_maxH isEqualType 0) then { _maxH = 0.34 };
    private _pw = pixelW;
    private _ph = pixelH;
    if (_pw <= 0 || { _ph <= 0 }) exitWith { [0, _maxW, (_maxH min 0.34)] };
    private _h = _maxW * _ph / (_pw * _aspect);
    private _w = _maxW;
    if (_h > _maxH) then {
        _h = _maxH;
        _w = _h * _pw * _aspect / _ph;
    };
    if (_w > _maxW) then { _w = _maxW };
    if (_h < 0.08) then { _h = 0.08 };
    [(_maxW - _w) * 0.5, _w, _h]
};

FAC_gui_besideBox = {
    params ["_row", "_width"];
    private _gap = 0.012;
    private _rightFrac = _row param [3, 0.46];
    if !(_rightFrac isEqualType 0) then { _rightFrac = 0.46 };
    if (_rightFrac < 0.25) then { _rightFrac = 0.25 };
    if (_rightFrac > 0.7) then { _rightFrac = 0.7 };
    private _rw = (_width - _gap) * _rightFrac;
    private _lw = (_width - _gap) - _rw;
    private _leftM = [_row param [1, []], _lw] call FAC_gui_measureRows;
    private _rightM = [_row param [2, []], _rw] call FAC_gui_measureRows;
    private _h = (_leftM select 1) max (_rightM select 1);
    if (_h > FAC_GUI_GAP) then { _h = _h - FAC_GUI_GAP };
    if (_h < 0.2) then { _h = 0.2 };
    [_lw, _rw, _gap, _h]
};

FAC_gui_entry = {
    params ["_spec", "_key", "_default"];
    private _found = _default;
    {
        if (_x isEqualType [] && { count _x > 0 } && { (_x select 0) isEqualTo _key }) exitWith {
            _found = _x;
        };
    } forEach _spec;
    _found
};

FAC_gui_styleColor = {
    params ["_style"];
    private _primary = if (!isNil "FAC_theme_btnPrimary") then { FAC_theme_btnPrimary } else { [0.32, 0.32, 0.36, 1] };
    private _neutral = if (!isNil "FAC_theme_btnNeutral") then { FAC_theme_btnNeutral } else { [0.22, 0.22, 0.24, 1] };
    private _danger = if (!isNil "FAC_theme_btnDanger") then { FAC_theme_btnDanger } else { [0.55, 0.12, 0.12, 1] };
    private _warn = if (!isNil "FAC_theme_btnWarn") then { FAC_theme_btnWarn } else { [0.42, 0.22, 0.20, 1] };
    private _idle = if (!isNil "FAC_theme_tabIdle") then { FAC_theme_tabIdle } else { [0.18, 0.18, 0.20, 1] };
    switch _style do {
        case "danger": { _danger };
        case "warn": { _warn };
        case "neutral": { _neutral };
        case "idle": { _idle };
        default { _primary };
    };
};

FAC_gui_bind = {
    params ["_ctrl", "_event", "_handler", "_action", "_mode", ["_args", []]];
    if (isNull _ctrl || { _action isEqualTo "" } || { _handler isEqualTo "" }) exitWith {};
    private _code = switch _mode do {
        case "this": { compile format ["['%1', _this] call %2", _action, _handler] };
        case "value": { compile format ["['%1', [_this select 1]] call %2", _action, _handler] };
        default { compile format ["['%1', %2] call %3", _action, str _args, _handler] };
    };
    _ctrl ctrlAddEventHandler [_event, _code];
};

// A fill list keeps its caption above the box. A picture beside it starts at the
// same y and has no caption, so the box ends short of the picture. Stretch the
// box so the caption top through the box bottom matches the picture.
// ctrlPosition is relative to the controls group, the same space as ctrlSetPosition.
// https://community.bistudio.com/wiki/ctrlPosition
FAC_gui_besideAlign = {
    params ["_display", "_row"];
    private _picIdc = -1;
    private _listIdc = -1;
    {
        {
            if (_x isEqualType [] && { count _x > 0 }) then {
                if ((_x select 0) isEqualTo "picture") then { _picIdc = _x param [1, -1] };
                if ((_x select 0) isEqualTo "list") then { _listIdc = _x param [5, -1] };
            };
        } forEach _x;
    } forEach [_row param [1, []], _row param [2, []]];
    if (_picIdc < 0 || { _listIdc < 0 }) exitWith {};
    private _pic = _display displayCtrl _picIdc;
    private _list = _display displayCtrl _listIdc;
    if (isNull _pic || { isNull _list }) exitWith {};
    private _pp = ctrlPosition _pic;
    private _lp = ctrlPosition _list;
    private _bottom = (_pp select 1) + (_pp select 3);
    private _newH = _bottom - (_lp select 1);
    if (_newH < 0.12) then { _newH = 0.12 };
    _list ctrlSetPosition [_lp select 0, _lp select 1, _lp select 2, _newH];
    _list ctrlCommit 0;
};

FAC_gui_put = {
    params ["_display", "_parent", "_class", "_idc", "_x", "_y", "_w", "_h", ["_text", ""]];
    // FACRscFormHint is a static line and clips. Draw the hint as structured text so it wraps.
    private _hint = _class isEqualTo "FACRscFormHint";
    if (_hint) then { _class = "FACRscFormStructured"; };
    private _ctrl = if (isNull _parent) then {
        _display ctrlCreate [_class, _idc]
    } else {
        _display ctrlCreate [_class, _idc, _parent]
    };
    if (isNull _ctrl) exitWith { controlNull };
    _ctrl ctrlSetPosition [_x, _y, _w, _h];
    if (_hint) then {
        _ctrl ctrlSetBackgroundColor [0, 0, 0, 0];
        if (_text != "") then {
            // ctrlSetStructuredText: https://community.bistudio.com/wiki/ctrlSetStructuredText
            _ctrl ctrlSetStructuredText parseText ("<t color='#9ea3ad' size='0.9'>" + _text + "</t>");
        };
    } else {
        if (_text != "") then { _ctrl ctrlSetText _text };
    };
    _ctrl ctrlCommit 0;
    _ctrl
};

// Side-by-side columns inside the current scroll. Height is the taller column.
FAC_gui_colsH = {
    params ["_row", "_width"];
    private _cols = _row param [1, []];
    private _n = count _cols;
    if (_n < 1) exitWith { 0 };
    private _gap = 0.012;
    private _cw = if (_n <= 1) then { _width } else { (_width - _gap * (_n - 1)) / _n };
    private _maxH = 0;
    {
        private _m = [_x, _cw] call FAC_gui_measureRows;
        private _h = (_m select 1) - FAC_GUI_GAP;
        if (_h < 0) then { _h = 0 };
        if (_h > _maxH) then { _maxH = _h };
    } forEach _cols;
    _maxH
};

// Height of one row, not counting the gap after it. Width matters for wrapping.
FAC_gui_rowHeight = {
    params ["_row", "_width"];
    if !(_row isEqualType []) exitWith { 0 };
    private _type = _row select 0;
    private _wrapH = {
        params ["_n", "_labelExtra"];
        if (_n < 1) exitWith { _labelExtra };
        private _gap = 0.008;
        private _colsPer = [_n, _width] call FAC_gui_segmentCols;
        _colsPer params ["_cols"];
        private _rowsN = ceil (_n / _cols);
        _labelExtra + (_rowsN * FAC_GUI_BTN_H) + ((_rowsN - 1) * _gap)
    };
    switch _type do {
        case "section": { FAC_GUI_SECTION_H };
        case "hint": { [_row param [1, ""], _width] call FAC_gui_hintH };
        case "spacer": { _row param [1, FAC_GUI_GAP] };
        case "segments": {
            private _extra = FAC_GUI_LABEL_H + ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_PAD;
            [count (_row param [3, []]), _extra] call _wrapH
        };
        case "buttonRow": {
            [count (_row param [1, []]), 0] call _wrapH
        };
        case "slider": {
            FAC_GUI_LABEL_H + ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_PAD + FAC_GUI_SLIDER_H
        };
        case "sliderApply": {
            ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_BTN_H
        };
        case "edit";
        case "combo": {
            FAC_GUI_LABEL_H + ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_PAD + FAC_GUI_INPUT_H
        };
        case "stepper": {
            FAC_GUI_LABEL_H + ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_PAD + FAC_GUI_BTN_H
        };
        case "list": {
            private _lh = _row param [4, 0.22];
            if !(_lh isEqualType 0) then { _lh = 0.22 };
            FAC_GUI_LABEL_H + ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_PAD + _lh
        };
        case "text";
        case "structured": { _row param [2, 0.08] };
        case "picture": {
            if ((_row param [2, 0.2]) isEqualTo "ratio") then {
                ([_row, _width] call FAC_gui_pictureSize) select 2
            } else {
                _row param [2, 0.2]
            };
        };
        case "beside": {
            ([_row, _width] call FAC_gui_besideBox) select 3
        };
        case "cols": { [_row, _width] call FAC_gui_colsH };
        case "band": { FAC_GUI_LABEL_H + FAC_GUI_PAD + 0.32 };
        case "button": {
            if !(_row param [7, true]) exitWith { 0 };
            ([_row param [2, ""], _width] call FAC_gui_hintH) + FAC_GUI_BTN_H
        };
        default { 0 };
    };
};

FAC_gui_measureRows = {
    params ["_rows", "_width"];
    private _y = 0;
    private _placed = [];
    {
        private _h = [_x, _width] call FAC_gui_rowHeight;
        _placed pushBack [_y, _h];
        _y = _y + _h + FAC_GUI_GAP;
    } forEach _rows;
    [_placed, _y]
};

FAC_gui_segmentCols = {
    params ["_n", "_width"];
    if (_n < 1) exitWith { [1, _width] };
    private _gap = 0.008;
    private _minW = 0.15;
    private _cols = _n;
    private _per = if (_n <= 1) then { _width } else { (_width - _gap * (_n - 1)) / _n };
    if (_per < _minW && { _n > 1 }) then {
        _cols = floor ((_width + _gap) / (_minW + _gap));
        if (_cols < 1) then { _cols = 1 };
        _per = (_width - _gap * (_cols - 1)) / _cols;
    };
    while { _cols > 1 && { (_n % _cols) == 1 } } do {
        _cols = _cols - 1;
        _per = (_width - _gap * (_cols - 1)) / _cols;
    };
    [_cols, _per]
};

FAC_gui_placeItems = {
    params ["_display", "_parent", "_items", "_x", "_y", "_width", "_handler", "_event", "_modeFromItem"];
    private _n = count _items;
    if (_n < 1) exitWith { 0 };
    private _gap = 0.008;
    private _colsPer = [_n, _width] call FAC_gui_segmentCols;
    _colsPer params ["_cols", "_per"];
    private _i = 0;
    while { _i < _n } do {
        private _item = _items select _i;
        private _text = _item param [0, ""];
        private _idc = _item param [1, -1];
        private _action = _item param [2, ""];
        private _args = _item param [3, []];
        private _style = _item param [4, "primary"];
        private _show = _item param [5, true];
        private _col = _i % _cols;
        private _rowN = floor (_i / _cols);
        private _ix = _x + _col * (_per + _gap);
        private _iy = _y + _rowN * (FAC_GUI_BTN_H + _gap);
        private _ctrl = [_display, _parent, "FACRscPrimaryBtn", _idc, _ix, _iy, _per, FAC_GUI_BTN_H, _text] call FAC_gui_put;
        if (!isNull _ctrl) then {
            _ctrl ctrlSetBackgroundColor ([_style] call FAC_gui_styleColor);
            _ctrl ctrlCommit 0;
            private _mode = if (_modeFromItem) then { _item param [6, "args"] } else { "args" };
            [_ctrl, _event, _handler, _action, _mode, _args] call FAC_gui_bind;
            if (!_show) then { _ctrl ctrlShow false };
        };
        _i = _i + 1;
    };
    private _rowsN = ceil (_n / _cols);
    (_rowsN * FAC_GUI_BTN_H) + ((_rowsN - 1) * _gap)
};

FAC_gui_placeCaption = {
    params ["_display", "_parent", "_text", "_idc", "_x", "_y", "_w", "_valueIdc", "_valueText"];
    private _capW = _w;
    if (_valueIdc >= 0 && { _valueIdc != _idc }) then { _capW = _w * 0.62 };
    if (_idc < 0) then { _idc = -1 };
    [_display, _parent, "FACRscFormLabel", _idc, _x, _y, _capW, FAC_GUI_LABEL_H, _text] call FAC_gui_put;
    if (_valueIdc >= 0 && { _valueIdc != _idc }) then {
        [_display, _parent, "FACRscFormLabel", _valueIdc, _x + _capW, _y, _w - _capW, FAC_GUI_LABEL_H, _valueText] call FAC_gui_put;
    };
};

// Places rows. Returns the y after the last gap. _mode "fit" gives a "fill" list the leftover height.
FAC_gui_placeRows = {
    params ["_display", "_parent", "_left", "_y0", "_w", "_maxH", "_rows", "_handler", ["_mode", "flow"]];
    private _fillH = 0.22;
    // A band keeps a real block of the page. The other rows continue in the same scroll.
    private _bandBox = (_maxH * 0.46) max 0.28;
    if (_bandBox > 0.42) then { _bandBox = 0.42 };
    if (_mode isEqualTo "fit") then {
        private _used = 0;
        private _fills = 0;
        {
            if ((_x select 0) isEqualTo "list" && { (_x param [4, 0.22]) isEqualTo "fill" }) then {
                _fills = _fills + 1;
                private _hintExtra = [_x param [2, ""], _w] call FAC_gui_hintH;
                _used = _used + FAC_GUI_LABEL_H + _hintExtra + FAC_GUI_PAD + FAC_GUI_GAP;
            } else {
                if ((_x select 0) isEqualTo "band") then {
                    _fills = _fills + 1;
                    _used = _used + FAC_GUI_LABEL_H + FAC_GUI_PAD + FAC_GUI_GAP;
                } else {
                    _used = _used + ([_x, _w] call FAC_gui_rowHeight) + FAC_GUI_GAP;
                };
            };
        } forEach _rows;
        if (_fills > 0) then {
            _fillH = ((_maxH - _used) / _fills) - FAC_GUI_GAP;
            if (_fillH < 0.12) then { _fillH = 0.12 };
        };
    };
    private _y = _y0;
    {
        private _row = _x;
        private _type = _row select 0;
        private _hint = "";
        switch _type do {
            case "section": {
                [_display, _parent, "FACRscSectionHdr", _row param [2, -1], _left, _y, _w, FAC_GUI_SECTION_H, format [" %1", _row param [1, ""]]] call FAC_gui_put;
            };
            case "hint": {
                private _hh = [_row param [1, ""], _w] call FAC_gui_hintH;
                [_display, _parent, "FACRscFormHint", -1, _left, _y, _w, _hh, _row param [1, ""]] call FAC_gui_put;
            };
            case "spacer": {};
            case "segments": {
                [_display, _parent, _row param [1, ""], -1, _left, _y, _w, -1, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                [_display, _parent, _row param [3, []], _left, _yy, _w, _handler, "ButtonClick", false] call FAC_gui_placeItems;
            };
            case "buttonRow": {
                [_display, _parent, _row param [1, []], _left, _y, _w, _handler, "ButtonClick", false] call FAC_gui_placeItems;
            };
            case "slider": {
                // caption, hint, captionIdc, valueIdc, sliderIdc, action, mode
                private _capIdc = _row param [3, -1];
                private _valIdc = _row param [4, -1];
                [_display, _parent, _row param [1, ""], _capIdc, _left, _y, _w, _valIdc, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                private _sl = [_display, _parent, "RscXSliderH", _row param [5, -1], _left, _yy, _w, FAC_GUI_SLIDER_H, ""] call FAC_gui_put;
                [_sl, "SliderPosChanged", _handler, _row param [6, ""], _row param [7, "this"], []] call FAC_gui_bind;
            };
            case "sliderApply": {
                // caption, hint, captionIdc, sliderIdc, action, mode, [button text, idc, action, args, style]
                _hint = _row param [2, ""];
                private _yy = _y;
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                private _btnSpec = _row param [7, []];
                private _btnW = 0.18;
                private _labW = 0.32;
                private _gap = 0.008;
                private _slW = _w - _labW - _btnW - (2 * _gap);
                if (_slW < 0.16) then {
                    _labW = 0.22;
                    _btnW = 0.16;
                    _slW = (_w - _labW - _btnW - (2 * _gap)) max 0.10;
                };
                private _rowH = FAC_GUI_BTN_H;
                private _labY = _yy + ((_rowH - FAC_GUI_LABEL_H) * 0.5);
                private _slY = _yy + ((_rowH - FAC_GUI_SLIDER_H) * 0.5);
                [_display, _parent, "FACRscFormLabel", _row param [3, -1], _left, _labY, _labW, FAC_GUI_LABEL_H, _row param [1, ""]] call FAC_gui_put;
                private _slApply = [_display, _parent, "RscXSliderH", _row param [4, -1], _left + _labW + _gap, _slY, _slW, FAC_GUI_SLIDER_H, ""] call FAC_gui_put;
                [_slApply, "SliderPosChanged", _handler, _row param [5, ""], _row param [6, "args"], []] call FAC_gui_bind;
                private _applyBtn = [_display, _parent, "FACRscPrimaryBtn", _btnSpec param [1, -1], _left + _w - _btnW, _yy, _btnW, _rowH, _btnSpec param [0, ""]] call FAC_gui_put;
                if (!isNull _applyBtn) then {
                    _applyBtn ctrlSetBackgroundColor ([_btnSpec param [4, "primary"]] call FAC_gui_styleColor);
                    _applyBtn ctrlCommit 0;
                    [_applyBtn, "ButtonClick", _handler, _btnSpec param [2, ""], "args", _btnSpec param [3, []]] call FAC_gui_bind;
                };
            };
            case "edit": {
                [_display, _parent, _row param [1, ""], _row param [3, -1], _left, _y, _w, -1, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                private _ed = [_display, _parent, "FACRscEditDark", _row param [4, -1], _left, _yy, _w, FAC_GUI_INPUT_H, ""] call FAC_gui_put;
                private _initial = _row param [7, ""];
                if (!isNull _ed && { _initial != "" }) then { _ed ctrlSetText _initial };
                [_ed, "KeyUp", _handler, _row param [5, ""], "args", _row param [6, []]] call FAC_gui_bind;
            };
            case "combo": {
                [_display, _parent, _row param [1, ""], _row param [3, -1], _left, _y, _w, -1, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                private _cb = [_display, _parent, "FACRscCombo", _row param [4, -1], _left, _yy, _w, FAC_GUI_INPUT_H, ""] call FAC_gui_put;
                [_cb, "LBSelChanged", _handler, _row param [5, ""], "args", _row param [6, []]] call FAC_gui_bind;
            };
            case "list": {
                [_display, _parent, _row param [1, ""], _row param [3, -1], _left, _y, _w, -1, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                private _lh = _row param [4, 0.22];
                if (_lh isEqualTo "fill") then { _lh = _fillH };
                if !(_lh isEqualType 0) then { _lh = 0.22 };
                private _lb = [_display, _parent, "FACRscListDark", _row param [5, -1], _left, _yy, _w, _lh, ""] call FAC_gui_put;
                [_lb, "LBSelChanged", _handler, _row param [6, ""], "args", _row param [7, []]] call FAC_gui_bind;
            };
            case "text": {
                [_display, _parent, "FACRscFormMulti", _row param [1, -1], _left, _y, _w, _row param [2, 0.06], _row param [3, ""]] call FAC_gui_put;
            };
            case "structured": {
                private _st = [_display, _parent, "FACRscFormStructured", _row param [1, -1], _left, _y, _w, _row param [2, 0.12], ""] call FAC_gui_put;
                private _raw = _row param [3, ""];
                if (!isNull _st && { _raw != "" }) then {
                    _st ctrlSetStructuredText parseText _raw;
                };
            };
            case "picture": {
                private _picH = _row param [2, 0.2];
                private _picW = _w;
                private _picX = _left;
                if (_picH isEqualTo "ratio") then {
                    private _box = [_row, _w] call FAC_gui_pictureSize;
                    _box params ["_xOff", "_sizedW", "_sizedH"];
                    _picX = _left + _xOff;
                    _picW = _sizedW;
                    _picH = _sizedH;
                    if (_xOff > 0.004) then {
                        [_display, _parent, "FACRscMainPanel", -1, _left, _y, _w, _picH, ""] call FAC_gui_put;
                    };
                };
                if !(_picH isEqualType 0) then { _picH = 0.2 };
                [_display, _parent, "FACRscPicture", _row param [1, -1], _picX, _y, _picW, _picH, ""] call FAC_gui_put;
            };
            case "beside": {
                private _box = [_row, _w] call FAC_gui_besideBox;
                _box params ["_lw", "_rw", "_colGap", "_bh"];
                [_display, _parent, _left, _y, _lw, _bh, _row param [1, []], _handler, "fit"] call FAC_gui_placeRows;
                [_display, _parent, _left + _lw + _colGap, _y, _rw, _bh, _row param [2, []], _handler, "fit"] call FAC_gui_placeRows;
                [_display, _row] call FAC_gui_besideAlign;
            };
            case "cols": {
                private _colList = _row param [1, []];
                private _nCols = count _colList;
                private _colGap = 0.012;
                private _cw = if (_nCols <= 1) then { _w } else { (_w - _colGap * (_nCols - 1)) / _nCols };
                private _ci = 0;
                while { _ci < _nCols } do {
                    [_display, _parent, _left + _ci * (_cw + _colGap), _y, _cw, 1, _colList select _ci, _handler, "flow"] call FAC_gui_placeRows;
                    _ci = _ci + 1;
                };
            };
            case "band": {
                private _items = _row param [1, []];
                private _nBand = count _items;
                private _bandGap = 0.012;
                private _bw = if (_nBand <= 1) then { _w } else { (_w - _bandGap * (_nBand - 1)) / _nBand };
                private _bandH = _bandBox;
                private _bi = 0;
                while { _bi < _nBand } do {
                    private _item = +(_items select _bi);
                    if ((_item select 0) isEqualTo "list") then { _item set [4, _bandH] };
                    [_display, _parent, _left + _bi * (_bw + _bandGap), _y, _bw, _bandH + 0.2, [_item], _handler, "flow"] call FAC_gui_placeRows;
                    _bi = _bi + 1;
                };
            };
            case "button": {
                if !(_row param [7, true]) then {
                    private _hiddenBtn = [_display, _parent, "FACRscPrimaryBtn", _row param [3, -1], 0, 0, 0, 0, ""] call FAC_gui_put;
                    if (!isNull _hiddenBtn) then { _hiddenBtn ctrlShow false };
                } else {
                    _hint = _row param [2, ""];
                    private _yy = _y;
                    if (_hint != "") then {
                        private _hh = [_hint, _w] call FAC_gui_hintH;
                        [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                        _yy = _yy + _hh;
                    };
                    private _btn = [_display, _parent, "FACRscPrimaryBtn", _row param [3, -1], _left, _yy, _w, FAC_GUI_BTN_H, _row param [1, ""]] call FAC_gui_put;
                    if (!isNull _btn) then {
                        _btn ctrlSetBackgroundColor ([_row param [6, "primary"]] call FAC_gui_styleColor);
                        _btn ctrlCommit 0;
                        [_btn, "ButtonClick", _handler, _row param [4, ""], "args", _row param [5, []]] call FAC_gui_bind;
                    };
                };
            };
            case "stepper": {
                [_display, _parent, _row param [1, ""], _row param [7, -1], _left, _y, _w, -1, ""] call FAC_gui_placeCaption;
                private _yy = _y + FAC_GUI_LABEL_H;
                _hint = _row param [2, ""];
                if (_hint != "") then {
                    private _hh = [_hint, _w] call FAC_gui_hintH;
                    [_display, _parent, "FACRscFormHint", -1, _left, _yy, _w, _hh, _hint] call FAC_gui_put;
                    _yy = _yy + _hh;
                };
                _yy = _yy + FAC_GUI_PAD;
                private _bw = 0.07;
                private _prev = [_display, _parent, "FACRscPrimaryBtn", _row param [3, -1], _left, _yy, _bw, FAC_GUI_BTN_H, "<"] call FAC_gui_put;
                [_display, _parent, "FACRscFormLabel", _row param [4, -1], _left + _bw + 0.008, _yy, (_w - (2 * _bw) - 0.016) max 0.08, FAC_GUI_BTN_H, ""] call FAC_gui_put;
                private _next = [_display, _parent, "FACRscPrimaryBtn", _row param [5, -1], _left + _w - _bw, _yy, _bw, FAC_GUI_BTN_H, ">"] call FAC_gui_put;
                private _act = _row param [6, ""];
                [_prev, "ButtonClick", _handler, _act, "args", [-1]] call FAC_gui_bind;
                [_next, "ButtonClick", _handler, _act, "args", [1]] call FAC_gui_bind;
            };
        };
        private _adv = [_row, _w] call FAC_gui_rowHeight;
        if ((_row select 0) isEqualTo "list" && { (_row param [4, 0]) isEqualTo "fill" }) then {
            private _hintExtra = [_row param [2, ""], _w] call FAC_gui_hintH;
            _adv = FAC_GUI_LABEL_H + _hintExtra + FAC_GUI_PAD + _fillH;
        };
        if ((_row select 0) isEqualTo "band") then {
            _adv = FAC_GUI_LABEL_H + FAC_GUI_PAD + _bandBox;
        };
        if (_adv > 0) then {
            _y = _y + _adv + FAC_GUI_GAP;
        };
    } forEach _rows;
    _y
};

FAC_gui_makeGroup = {
    params ["_display", "_idc", "_x", "_y", "_w", "_h"];
    private _g = [_display, controlNull, "FACRscScrollGroup", _idc, _x, _y, _w, _h, ""] call FAC_gui_put;
    _g
};

// ctrlScrollValues returns [vertical, horizontal], each 0..1.
// https://community.bistudio.com/wiki/ctrlScrollValues
// ctrlSetScrollValues [vScroll, hScroll] sets the same pair.
// https://community.bistudio.com/wiki/ctrlSetScrollValues
// MouseZChanged: the control and the wheel change. Drop the "on" prefix.
// https://community.bistudio.com/wiki/User_Interface_Event_Handlers#onMouseZChanged
FAC_gui_armScroll = {
    params ["_display", "_group", "_contentY", "_viewH"];
    if (isNull _group) exitWith {};
    if (_contentY <= (_viewH - 0.008)) exitWith {};
    [_display, _group, "RscText", -1, 0, _contentY, 0.01, 0.01, ""] call FAC_gui_put;
    _group ctrlAddEventHandler ["MouseZChanged", {
        params ["_grp", "_z"];
        private _cur = ctrlScrollValues _grp;
        private _h = _cur select 1;
        private _v = (_cur select 0) - (_z * 0.12);
        if (_v < 0) then { _v = 0 };
        if (_v > 1) then { _v = 1 };
        _grp ctrlSetScrollValues [_v, _h];
    }];
};

FAC_gui_placeBody = {
    params ["_display", "_content", "_bx", "_by", "_bw", "_bh", "_handler", "_groupIdc"];
    private _pages = [];
    if !(_content isEqualType []) exitWith { _pages };
    private _kind = if (count _content > 0) then { _content select 0 } else { "" };
    if (_kind isEqualTo "columns") then {
        private _left = _content param [1, []];
        private _right = _content param [2, []];
        private _gap = 0.016;
        private _lw = (_bw - _gap) * 0.40;
        private _rw = _bw - _gap - _lw;
        private _lg = [_display, _groupIdc, _bx, _by, _lw, _bh] call FAC_gui_makeGroup;
        private _rg = [_display, _groupIdc + 1, _bx + _lw + _gap, _by, _rw, _bh] call FAC_gui_makeGroup;
        if (!isNull _lg) then {
            private _yL = [_display, _lg, 0.008, 0.008, _lw - 0.028, _bh - 0.032, _left, _handler, "fit"] call FAC_gui_placeRows;
            [_display, _lg, _yL, _bh] call FAC_gui_armScroll;
        };
        if (!isNull _rg) then {
            private _rightMode = _content param [3, "flow"];
            if !(_rightMode in ["fit", "flow"]) then { _rightMode = "flow" };
            private _yR = [_display, _rg, 0.008, 0.008, _rw - 0.028, _bh - 0.032, _right, _handler, _rightMode] call FAC_gui_placeRows;
            [_display, _rg, _yR, _bh] call FAC_gui_armScroll;
        };
        _display setVariable [format ["FAC_gui_pair_%1", _groupIdc], _rg];
        if (!isNull _lg) then { _pages = [[_groupIdc, _lg]] };
    } else {
        if (_kind isEqualTo "pin") then {
            private _top = _content param [1, []];
            private _bottom = _content param [2, []];
            private _bH = _content param [3, 0.34];
            private _topH = _bh - _bH - 0.01;
            if (_topH < 0.06) then {
                _topH = 0.06;
                _bH = (_bh - _topH - 0.01) max 0.12;
            };
            private _g = [_display, _groupIdc, _bx, _by, _bw, _topH] call FAC_gui_makeGroup;
            if (!isNull _g) then {
                private _endY = 0.008;
                if (_top isEqualType [] && { count _top > 0 } && { (_top select 0) isEqualTo "columns" }) then {
                    private _gap = 0.016;
                    private _colW = ((_bw - 0.03) - _gap) * 0.5;
                    private _yL = [_display, _g, 0.008, 0.008, _colW, _topH - 0.016, _top param [1, []], _handler, "flow"] call FAC_gui_placeRows;
                    private _yR = [_display, _g, 0.008 + _colW + _gap, 0.008, _colW, _topH - 0.016, _top param [2, []], _handler, "flow"] call FAC_gui_placeRows;
                    _endY = _yL max _yR;
                } else {
                    _endY = [_display, _g, 0.008, 0.008, _bw - 0.03, _topH - 0.016, _top, _handler, "flow"] call FAC_gui_placeRows;
                };
                [_display, _g, _endY, _topH] call FAC_gui_armScroll;
                _pages = [[_groupIdc, _g]];
            };
            private _bg = [_display, _groupIdc + 1, _bx, _by + _topH + 0.01, _bw, _bH] call FAC_gui_makeGroup;
            if (!isNull _bg) then {
                private _n = count _bottom;
                private _gap = 0.012;
                private _innerW = _bw - 0.02;
                private _cw = if (_n <= 1) then { _innerW } else { (_innerW - _gap * (_n - 1)) / _n };
                private _i = 0;
                while { _i < _n } do {
                    private _colRows = _bottom select _i;
                    private _cx = 0.008 + _i * (_cw + _gap);
                    [_display, _bg, _cx, 0.008, _cw, _bH - 0.016, _colRows, _handler, "fit"] call FAC_gui_placeRows;
                    _i = _i + 1;
                };
                _display setVariable [format ["FAC_gui_pair_%1", _groupIdc], _bg];
            };
        } else {
            if (_kind isEqualTo "fit") then {
                private _rows = _content param [1, []];
                private _g = [_display, _groupIdc, _bx, _by, _bw, _bh] call FAC_gui_makeGroup;
                if (!isNull _g) then {
                    private _endY = [_display, _g, 0.008, 0.008, _bw - 0.03, _bh - 0.016, _rows, _handler, "fit"] call FAC_gui_placeRows;
                    [_display, _g, _endY, _bh] call FAC_gui_armScroll;
                    _pages = [[_groupIdc, _g]];
                };
            } else {
                private _g = [_display, _groupIdc, _bx, _by, _bw, _bh] call FAC_gui_makeGroup;
                if (!isNull _g) then {
                    private _endY = [_display, _g, 0.008, 0.008, _bw - 0.03, _bh - 0.016, _content, _handler, "flow"] call FAC_gui_placeRows;
                    [_display, _g, _endY, _bh] call FAC_gui_armScroll;
                    _pages = [[_groupIdc, _g]];
                };
            };
        };
    };
    _pages
};

FAC_gui_showPage = {
    params ["_display", "_name"];
    if (isNull _display) exitWith {};
    private _pages = _display getVariable ["FAC_gui_pages", []];
    {
        _x params ["_pageName", "_group"];
        private _on = _pageName isEqualTo _name;
        if (!isNull _group) then { _group ctrlShow _on };
        private _pair = _display getVariable [format ["FAC_gui_pair_%1", ctrlIDC _group], controlNull];
        if (!isNull _pair) then { _pair ctrlShow _on };
    } forEach _pages;
    private _tabs = _display getVariable ["FAC_gui_tabCtrls", []];
    {
        _x params ["_pageName", "_idc"];
        private _c = _display displayCtrl _idc;
        if (!isNull _c) then { [_c, _pageName isEqualTo _name] call FAC_theme_applyTab };
    } forEach _tabs;
    _display setVariable ["FAC_gui_page", _name];
};

FAC_gui_frameRect = {
    params ["_spec"];
    private _entry = [_spec, "frame", ["frame", "full"]] call FAC_gui_entry;
    private _frame = _entry param [1, "full"];
    if (_frame isEqualType [] && { count _frame == 4 }) exitWith { _frame };
    if (_frame isEqualTo "compact") exitWith { [0.22, 0.12, 0.56, 0.76] };
    [0.02, 0.02, 0.96, 0.96]
};

FAC_gui_move = {
    params ["_display", "_idc", "_x", "_y", "_w", "_h"];
    private _c = _display displayCtrl _idc;
    if (isNull _c) exitWith {};
    _c ctrlSetPosition [_x, _y, _w, _h];
    _c ctrlCommit 0;
};

FAC_gui_build = {
    params ["_display", "_spec"];
    if (isNull _display) exitWith {};
    if (isNull (_display displayCtrl 59900)) exitWith {};
    if (_display getVariable ["FAC_gui_built", false]) exitWith {};
    _display setVariable ["FAC_gui_built", true];

    private _handlerEntry = [_spec, "handler", ["handler", ""]] call FAC_gui_entry;
    private _handler = _handlerEntry param [1, ""];
    _display setVariable ["FAC_gui_handler", _handler];

    private _rect = [_spec] call FAC_gui_frameRect;
    _rect params ["_fx", "_fy", "_fw", "_fh"];
    [_display, 59900, _fx, _fy, _fw, _fh] call FAC_gui_move;
    [_display, 59904, _fx, _fy, _fw, 0.065] call FAC_gui_move;

    private _titleEntry = [_spec, "title", ["title", ""]] call FAC_gui_entry;
    private _title = _titleEntry param [1, ""];
    private _titleW = ((count _title) * 0.024) max 0.18;
    if (_titleW > 0.32) then { _titleW = 0.32 };
    private _titleCtrl = _display displayCtrl 59901;
    if (!isNull _titleCtrl) then {
        _titleCtrl ctrlSetText _title;
        _titleCtrl ctrlSetPosition [_fx + 0.015, _fy + 0.008, _titleW, 0.050];
        _titleCtrl ctrlCommit 0;
    };

    private _refreshEntry = [_spec, "refresh", ["refresh", true]] call FAC_gui_entry;
    private _showRefresh = _refreshEntry param [1, true];
    private _refresh = _display displayCtrl 59902;
    private _close = _display displayCtrl 59903;
    if (!isNull _close) then {
        _close ctrlSetPosition [_fx + _fw - 0.058, _fy + 0.010, 0.046, 0.046];
        _close ctrlCommit 0;
    };
    if (!isNull _refresh) then {
        _refresh ctrlSetPosition [_fx + _fw - 0.158, _fy + 0.010, 0.092, 0.046];
        _refresh ctrlCommit 0;
        _refresh ctrlShow _showRefresh;
        if (_showRefresh) then {
            [_refresh, "ButtonClick", _handler, "headerRefresh", "args", []] call FAC_gui_bind;
        };
    };

    private _headerBtns = ([_spec, "headerButtons", ["headerButtons", []]] call FAC_gui_entry) param [1, []];
    private _tabEntry = [_spec, "tabs", ["tabs", []]] call FAC_gui_entry;
    private _tabs = _tabEntry param [1, []];
    private _tabX = _fx + _titleW + 0.03;
    private _tabRight = _fx + _fw - 0.17 - (0.16 * (count _headerBtns));
    private _tabBudget = (_tabRight - _tabX) max 0.12;
    private _tabW = if (count _tabs < 1) then { 0.12 } else { (_tabBudget / (count _tabs)) min 0.20 };
    private _tabCtrls = [];
    private _ti = 0;
    {
        _x params ["_pageName", "_label", "_idc", ["_action", "setTab"], ["_args", []]];
        if (count _args < 1) then { _args = [_pageName] };
        private _tb = [_display, controlNull, "FACRscTabBtn", _idc, _tabX + _ti * (_tabW + 0.006), _fy + 0.010, _tabW, 0.046, _label] call FAC_gui_put;
        [_tb, "ButtonClick", _handler, _action, "args", _args] call FAC_gui_bind;
        _tabCtrls pushBack [_pageName, _idc];
        _ti = _ti + 1;
    } forEach _tabs;
    _display setVariable ["FAC_gui_tabCtrls", _tabCtrls];

    private _hx = _tabRight;
    {
        _x params ["_label", "_idc", "_action", ["_args", []], ["_style", "warn"]];
        private _hb = [_display, controlNull, "FACRscPrimaryBtn", _idc, _hx, _fy + 0.010, 0.15, 0.046, _label] call FAC_gui_put;
        if (!isNull _hb) then {
            _hb ctrlSetBackgroundColor ([_style] call FAC_gui_styleColor);
            _hb ctrlCommit 0;
            [_hb, "ButtonClick", _handler, _action, "args", _args] call FAC_gui_bind;
        };
        _hx = _hx + 0.156;
    } forEach _headerBtns;

    private _footerItems = ([_spec, "footer", ["footer", []]] call FAC_gui_entry) param [1, []];
    private _footerH = if (count _footerItems > 0) then { 0.062 } else { 0 };
    private _bodyY = _fy + 0.078;
    private _bodyH = _fh - 0.078 - _footerH - 0.012;
    private _bodyX = _fx + 0.015;
    private _bodyW = _fw - 0.030;
    [_display, 59905, _bodyX - 0.005, _bodyY - 0.006, _bodyW + 0.010, _bodyH + _footerH + 0.010] call FAC_gui_move;
    private _sharedRows = ([_spec, "shared", ["shared", []]] call FAC_gui_entry) param [1, []];
    if (count _sharedRows > 0) then {
        private _measured = [_sharedRows, _bodyW - 0.03] call FAC_gui_measureRows;
        private _sharedH = (_measured select 1) min (_bodyH * 0.45);
        private _sg = [_display, 59790, _bodyX, _bodyY, _bodyW, _sharedH] call FAC_gui_makeGroup;
        if (!isNull _sg) then {
            private _endY = [_display, _sg, 0.008, 0.004, _bodyW - 0.03, _sharedH - 0.012, _sharedRows, _handler, "flow"] call FAC_gui_placeRows;
            [_display, _sg, _endY, _sharedH] call FAC_gui_armScroll;
        };
        _bodyY = _bodyY + _sharedH + 0.008;
        _bodyH = (_bodyH - _sharedH - 0.008) max 0.12;
    };
    private _dockRows = ([_spec, "dock", ["dock", []]] call FAC_gui_entry) param [1, []];
    if (count _dockRows > 0) then {
        private _measuredDock = [_dockRows, _bodyW - 0.02] call FAC_gui_measureRows;
        private _dockH = ((_measuredDock select 1) + 0.008) min 0.22;
        private _dockY = _bodyY + _bodyH - _dockH;
        [_display, controlNull, _bodyX, _dockY, _bodyW, _dockH, _dockRows, _handler, "flow"] call FAC_gui_placeRows;
        _bodyH = (_bodyH - _dockH - 0.008) max 0.12;
    };
    _display setVariable ["FAC_gui_body", [_bodyX, _bodyY, _bodyW, _bodyH]];

    if (_footerH > 0) then {
        private _fyBtn = _fy + _fh - _footerH - 0.008;
        [_display, controlNull, _bodyX, _fyBtn, _bodyW, _footerH, [["buttonRow", _footerItems]], _handler, "flow"] call FAC_gui_placeRows;
    };

    private _floats = ([_spec, "float", ["float", []]] call FAC_gui_entry) param [1, []];
    {
        // [class, idc, x, y, w, h, text, show]
        _x params ["_class", "_idc", "_x", "_y", "_w", "_h", ["_text", ""], ["_show", true], ["_action", ""], ["_args", []]];
        private _c = [_display, controlNull, _class, _idc, _x, _y, _w, _h, _text] call FAC_gui_put;
        if (!isNull _c) then {
            if (_action != "") then { [_c, "ButtonClick", _handler, _action, "args", _args] call FAC_gui_bind };
            if (!_show) then { _c ctrlShow false };
        };
    } forEach _floats;

    private _pageGroups = [];
    private _nextIdc = 59800;
    private _default = ([_spec, "default", ["default", ""]] call FAC_gui_entry) param [1, ""];
    {
        if (_x isEqualType [] && { (_x select 0) isEqualTo "page" }) then {
            private _pageName = _x param [1, ""];
            private _content = _x param [2, []];
            if (_default isEqualTo "") then { _default = _pageName };
            private _made = [_display, _content, _bodyX, _bodyY, _bodyW, _bodyH, _handler, _nextIdc] call FAC_gui_placeBody;
            {
                _x params ["_gid", "_group"];
                _pageGroups pushBack [_pageName, _group];
            } forEach _made;
            private _kind = if (_content isEqualType [] && { count _content > 0 }) then { _content select 0 } else { "" };
            _nextIdc = _nextIdc + (if (_kind in ["columns", "pin"]) then { 2 } else { 1 });
        };
    } forEach _spec;
    _display setVariable ["FAC_gui_pages", _pageGroups];
    if (_default != "") then {
        [_display, _default] call FAC_gui_showPage;
    };
};

// Pure check used by the local layout test. No display required.
FAC_gui_auditSpec = {
    params ["_spec"];
    private _errors = [];
    private _idcs = [];
    private _noteIdc = {
        params ["_idc", "_where"];
        if (_idc isEqualType 0 && { _idc >= 0 }) then {
            if (_idc in _idcs) then {
                _errors pushBack format ["duplicate idc %1 at %2", _idc, _where];
            } else {
                _idcs pushBack _idc;
            };
        };
    };
    private _walkRows = {
        params ["_rows", "_where"];
        {
            if !(_x isEqualType []) then {
                _errors pushBack format ["row is not an array at %1", _where];
            } else {
                private _type = _x select 0;
                private _known = ["section", "hint", "spacer", "segments", "buttonRow", "slider", "sliderApply", "edit", "combo", "list", "text", "structured", "picture", "beside", "cols", "band", "button", "stepper"];
                if !(_type in _known) then {
                    _errors pushBack format ["unknown row %1 at %2", _type, _where];
                };
                switch _type do {
                    case "segments": {
                        { [_x param [1, -1], _where] call _noteIdc } forEach (_x param [3, []]);
                    };
                    case "buttonRow": {
                        { [_x param [1, -1], _where] call _noteIdc } forEach (_x param [1, []]);
                    };
                    case "slider": {
                        [_x param [3, -1], _where] call _noteIdc;
                        [_x param [4, -1], _where] call _noteIdc;
                        [_x param [5, -1], _where] call _noteIdc;
                    };
                    case "sliderApply": {
                        [_x param [3, -1], _where] call _noteIdc;
                        [_x param [4, -1], _where] call _noteIdc;
                        [(_x param [7, []]) param [1, -1], _where] call _noteIdc;
                    };
                    case "edit";
                    case "combo": {
                        [_x param [3, -1], _where] call _noteIdc;
                        [_x param [4, -1], _where] call _noteIdc;
                    };
                    case "list": {
                        [_x param [3, -1], _where] call _noteIdc;
                        [_x param [5, -1], _where] call _noteIdc;
                    };
                    case "text";
                    case "structured";
                    case "picture": {
                        [_x param [1, -1], _where] call _noteIdc;
                    };
                    case "beside": {
                        [_x param [1, []], _where + "/left"] call _walkRows;
                        [_x param [2, []], _where + "/right"] call _walkRows;
                    };
                    case "cols": {
                        { [_x, _where + "/col"] call _walkRows } forEach (_x param [1, []]);
                    };
                    case "band": {
                        [_x param [1, []], _where + "/band"] call _walkRows;
                    };
                    case "button": {
                        [_x param [3, -1], _where] call _noteIdc;
                    };
                    case "stepper": {
                        [_x param [3, -1], _where] call _noteIdc;
                        [_x param [4, -1], _where] call _noteIdc;
                        [_x param [5, -1], _where] call _noteIdc;
                        [_x param [7, -1], _where] call _noteIdc;
                    };
                };
            };
        } forEach _rows;
    };
    private _walkContent = {
        params ["_content", "_where"];
        if !(_content isEqualType []) exitWith {
            _errors pushBack format ["page content missing at %1", _where];
        };
        if (count _content < 1) exitWith {};
        private _kind = _content select 0;
        if (_kind isEqualTo "columns") then {
            [_content param [1, []], _where + "/left"] call _walkRows;
            [_content param [2, []], _where + "/right"] call _walkRows;
        } else {
            if (_kind isEqualTo "pin") then {
                private _top = _content param [1, []];
                if (_top isEqualType [] && { count _top > 0 } && { (_top select 0) isEqualTo "columns" }) then {
                    [_top param [1, []], _where + "/left"] call _walkRows;
                    [_top param [2, []], _where + "/right"] call _walkRows;
                } else {
                    [_top, _where + "/top"] call _walkRows;
                };
                { [_x, _where + "/pin"] call _walkRows } forEach (_content param [2, []]);
            } else {
                if (_kind isEqualTo "fit") then {
                    [_content param [1, []], _where] call _walkRows;
                } else {
                    [_content, _where] call _walkRows;
                };
            };
        };
    };
    private _pages = 0;
    {
        if (_x isEqualType [] && { count _x > 0 }) then {
            switch (_x select 0) do {
                case "page": {
                    _pages = _pages + 1;
                    [_x param [2, []], _x param [1, "page"]] call _walkContent;
                };
                case "tabs": {
                    { [_x param [2, -1], "tab"] call _noteIdc } forEach (_x param [1, []]);
                };
                case "footer": {
                    { [_x param [1, -1], "footer"] call _noteIdc } forEach (_x param [1, []]);
                };
                case "headerButtons": {
                    { [_x param [1, -1], "header"] call _noteIdc } forEach (_x param [1, []]);
                };
                case "float": {
                    { [_x param [1, -1], "float"] call _noteIdc } forEach (_x param [1, []]);
                };
                case "shared": {
                    [_x param [1, []], "shared"] call _walkRows;
                };
                case "dock": {
                    [_x param [1, []], "dock"] call _walkRows;
                };
            };
        };
    } forEach _spec;
    if (_pages < 1) then { _errors pushBack "spec has no page" };
    _errors
};

FAC_gui_selfTest = {
    private _rows = [
        ["section", "Enemy AI"],
        ["segments", "OPFOR population", "Scales infantry. Normal is 1x.", [
            ["Very low", 1, "setOpforPop", ["VeryLow"]],
            ["Low", 2, "setOpforPop", ["Low"]],
            ["Normal", 3, "setOpforPop", ["Normal"]],
            ["High", 4, "setOpforPop", ["High"]],
            ["Very high", 5, "setOpforPop", ["VeryHigh"]],
            ["Insane", 6, "setOpforPop", ["Insane"]]
        ]]
    ];
    private _wide = [_rows, 0.90] call FAC_gui_measureRows;
    private _narrow = [_rows, 0.40] call FAC_gui_measureRows;
    private _sectionH = [[["section", "A"]], 0.9] call FAC_gui_measureRows;
    private _slideH = [[["sliderApply", "Fuel: 0%", "", 1, 2, "go", "args", ["Apply", 3, "apply", [], "primary"]]], 0.9] call FAC_gui_measureRows;
    private _ok = (_wide select 1) > 0.05;
    _ok = _ok && { (_narrow select 1) > (_wide select 1) };
    _ok = _ok && { abs ((_sectionH select 1) - (FAC_GUI_SECTION_H + FAC_GUI_GAP)) < 0.0001 };
    _ok = _ok && { abs ((_slideH select 1) - (FAC_GUI_BTN_H + FAC_GUI_GAP)) < 0.0001 };
    private _bad = [[["nope", "x"]]] call FAC_gui_auditSpec;
    _ok = _ok && { count _bad > 0 };
    private _dup = [[
        ["page", "a", [
            ["button", "One", "", 10, "go", [], "primary"]
        ]],
        ["page", "b", [
            ["button", "Two", "", 10, "go", [], "primary"]
        ]]
    ]] call FAC_gui_auditSpec;
    _ok && { count _dup > 0 }
};
