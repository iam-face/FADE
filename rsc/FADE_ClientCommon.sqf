// =============================================================================
// FADE_ClientCommon.sqf  -  shared client helpers (diary, intel UI); compile early
// =============================================================================

if (!hasInterface) exitWith {};

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

// Legacy aliases (CivTalk / Intel modules).
FADE_civTalk_escapeForStructuredText = FADE_client_escapeForDiary;
FADE_intel_escapeForDiary = FADE_client_escapeForDiary;

FADE_civTalk_clientAppendIntelDiary = {
    params [["_civName", "Civilian"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "HUMINT"]];
    [_civName, _whenStr, _bodyRaw, _kind] call FADE_client_appendIntelDiary;
};

FADE_intel_clientAppendIntelDiary = {
    params [["_headerName", "Intel"], ["_whenStr", ""], ["_bodyRaw", ""], ["_kind", "Report"]];
    [_headerName, _whenStr, _bodyRaw, _kind] call FADE_client_appendIntelDiary;
};

missionNamespace setVariable ["FADE_client_escapeForDiary", FADE_client_escapeForDiary];
missionNamespace setVariable ["FADE_client_appendIntelDiary", FADE_client_appendIntelDiary];
missionNamespace setVariable ["FADE_civTalk_escapeForStructuredText", FADE_civTalk_escapeForStructuredText];
missionNamespace setVariable ["FADE_intel_escapeForDiary", FADE_intel_escapeForDiary];
missionNamespace setVariable ["FADE_civTalk_clientAppendIntelDiary", FADE_civTalk_clientAppendIntelDiary];
missionNamespace setVariable ["FADE_intel_clientAppendIntelDiary", FADE_intel_clientAppendIntelDiary];
