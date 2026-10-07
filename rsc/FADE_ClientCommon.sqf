// =============================================================================
// FADE_ClientCommon.sqf  -  shared client helpers (diary, intel UI); compile early
// =============================================================================

if (!hasInterface) exitWith {};

// Procedural texture string helpers (HQ main board; server defines same in FADE_Common.sqf).
if (isNil "FADE_textureText_sanitize") then {
    FADE_textureText_sanitize = {
        params [["_text", ""]];
        if (!(_text isEqualType "")) then { _text = str _text };
        private _out = [];
        {
            switch (_x) do {
                case 34: { _out append (toArray "'") };
                case 92: { _out pushBack 47 };
                case 10;
                case 13;
                case 9: { _out pushBack 32 };
                default { _out pushBack _x };
            };
        } forEach (toArray _text);
        toString _out
    };
    FADE_textureText_wrap = {
        params [["_text", ""], ["_maxChars", 40], ["_newline", toString [92, 110]]];
        if (_text == "") exitWith { "" };
        private _words = _text splitString " ";
        private _lines = [];
        private _line = "";
        {
            private _word = _x;
            private _test = if (_line == "") then { _word } else { _line + " " + _word };
            if ((count _test) > _maxChars && { _line != "" }) then {
                _lines pushBack _line;
                _line = _word;
            } else {
                _line = _test;
            };
        } forEach _words;
        if (_line != "") then { _lines pushBack _line };
        _lines joinString _newline
    };
};

// Escape user text for diary / structured-text HTML (CivTalk + Intel).
FADE_client_escapeForDiary = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = str _s };
    private _a = _s splitString "&";
    _s = _a joinString "&amp;";
    _a = _s splitString "<";
    _s = _a joinString "&lt;";
    _a = _s splitString ">";
    _s = _a joinString "&gt;";
    private _nl = toString [10];
    _a = _s splitString _nl;
    _s = _a joinString "<br/>";
    _s
};

// Append one Intel diary record (Briefing.sqf subject "FAC_Intel").
FADE_client_appendIntelDiary = {
    params [["_headerName", "Intel"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "Report"]];
    if (!hasInterface) exitWith {};
    if (isNull player) exitWith {};
    if !(_bodyRaw isEqualType "") then { _bodyRaw = str _bodyRaw };
    player createDiarySubject ["FAC_Intel", "Intel"];
    private _escBody = [_bodyRaw] call FADE_client_escapeForDiary;
    private _escHdr = [_headerName] call FADE_client_escapeForDiary;
    private _escWhen = [_whenStr] call FADE_client_escapeForDiary;
    private _escKind = [_kind] call FADE_client_escapeForDiary;
    private _html = (
        "<font color='#87CEEB'>" + _escHdr + "</font><br/><font color='#A0B4C8'>" + _escWhen + " | " + _escKind + "</font><br/><br/>"
        + "<font color='#FFFFFF'>" + _escBody + "</font>"
    );
    private _title = _headerName;
    if ((count _title) > 40) then { _title = (_title select [0, 37]) + "..." };
    player createDiaryRecord ["FAC_Intel", [_title, _html]];
};

FADE_civTalk_clientAppendIntelDiary = {
    params [["_civName", "Civilian"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "HUMINT"]];
    [_civName, _whenStr, _bodyRaw, _kind] call FADE_client_appendIntelDiary;
};

FADE_intel_clientAppendIntelDiary = {
    params [["_headerName", "Intel"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "Report"]];
    [_headerName, _whenStr, _bodyRaw, _kind] call FADE_client_appendIntelDiary;
};

// Shared BIS_fnc_holdActionAdd tail: duplicate icon, empty start/progress/interrupt, priority 0.
FADE_client_addHoldAction = {
    params ["_obj", "_title", "_icon", "_condShow", "_condProgress", "_onComplete", "_duration"];
    [
        _obj,
        _title,
        _icon,
        _icon,
        _condShow,
        _condProgress,
        {},
        {},
        _onComplete,
        {},
        [],
        _duration,
        0,
        false,
        false
    ] call BIS_fnc_holdActionAdd
};

missionNamespace setVariable ["FADE_client_escapeForDiary", FADE_client_escapeForDiary];
missionNamespace setVariable ["FADE_client_appendIntelDiary", FADE_client_appendIntelDiary];
missionNamespace setVariable ["FADE_civTalk_clientAppendIntelDiary", FADE_civTalk_clientAppendIntelDiary];
missionNamespace setVariable ["FADE_intel_clientAppendIntelDiary", FADE_intel_clientAppendIntelDiary];
missionNamespace setVariable ["FADE_client_addHoldAction", FADE_client_addHoldAction];
