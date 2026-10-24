// =============================================================================
// MissionsGui.sqf - Manage missions (select, start, status)
// =============================================================================
// Weather and time are managed via Scenario GUI (Manage Scenario).
// Browse is a card grid (name, Global/Single, blurb, task icon). The hidden
// listbox 60120 still holds the selection for Start.

// [displayName, missionId, description, "Global"|"Single"] - stream is for logic; list shows [G]/[S]
// Keep [0]/[1] in sync with rsc/FAC_MissionTypeLabels.sqf (server mission intro subtitle).
private _missionListRaw = [
    ["Area of Operations", "AreaOfOperations", "Multi-objective fight across a wide sector. Plenty of room to manoeuvre; contact is steady once you commit. [G]", "Global"],
    ["Asset Retrieval", "AssetRetrieval", "Recover priority equipment from enemy ground, then extract. Sites are usually guarded. [G]", "Global"],
    ["CAS / Fire Support", "CAS", "On-call air or indirect fires for friendlies already in contact. ID friendlies and deconflict before you shoot. [G]", "Global"],
    ["Cargo / Resupply", "Cargo", "Fly supplies to a forward camp. Land to unload or sling as briefed; keep PZ/LZ discipline. [S]", "Single"],
    ["CASEVAC", "CASEVAC", "Lift wounded to medical care. Fast, careful pickups; LZs can be tight or informal. [S]", "Single"],
    ["Clear Area", "ClearArea", "Assault and hold an enemy town or camp. Expect close fighting and reinforced buildings. [G]", "Global"],
    ["CSAR", "CSAR", "Find and recover personnel at a crash site. Treat the area as hostile until you own it. [G]", "Global"],
    ["Escape & Evasion", "EscapeEvasion", "Separated personnel evade out of hostile ground while a rescue force coordinates recovery. Limited navigation aids. [G]", "Global"],
    ["Geo-Guesser", "GeoGuesser", "Navigation drill: drop at a random spot, click the map where you think you are. Faster guesses score higher. [G]", "Global"],
    ["Hostage", "Hostage", "Pull civilians out of a defended built-up site. Move fast, control the scene, keep hostiles and civs apart. [G]", "Global"],
    ["HVT", "HVT", "Find a priority target in built-up ground. Kill or capture, then get them (or confirmation) back to base. [G]", "Global"],
    ["Intercept Convoy", "InterceptConvoy", "Stop a moving enemy column before it finishes its route. Escorts react quickly. [G]", "Global"],
    ["Invasion", "Invasion", "OPFOR beachhead push inland. Retake the INVASION zone to win. [G]", "Global"],
    ["Mine Clearing", "MineClearing", "Clear mines or IEDs on a short road segment. Slow recon and standard clearance drills. [S]", "Single"],
    ["Operation", "Operation", "Linked fights across several zones. Clear outer sites, then take the OPFOR HQ hub. [G]", "Global"],
    ["Point Defense", "PointDefense", "Occupy and hold a marked point against assault waves for a set duration. Timer starts when players enter the zone. [G]", "Global"],
    ["Raid", "Raid", "Three map-spread objectives (mixed task types) tied to one enemy network. Intel tightens as you recon. [G]", "Global"],
    ["Search & Destroy", "SearchDestroy", "Find enemy ammo caches in a marked zone (burning barrels mark buildings). Task gives count and destroy %. [G]", "Global"],
    ["Troop Extract", "TroopExtract", "Pick up a ground team and RTB. Hold LZ discipline and keep loading calm. [S]", "Single"],
    ["Troop Insert", "TroopInsert", "Lift troops from base into a surveyed LZ. Clean landings, fast dismounts. [S]", "Single"]
];
private _disabledTypes = missionNamespace getVariable ["FADE_disabledMissionTypes", []];
_missionListRaw = _missionListRaw select { !((_x select 1) in _disabledTypes) };
private _sorted = [_missionListRaw, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy;
if (isNil "_sorted" || { !(_sorted isEqualType []) }) then { _sorted = _missionListRaw };
missionNamespace setVariable ["FAC_missionsGui_missionList", _sorted];

// Default intro when no mission selected
FAC_missionsGui_defaultDesc = "Select a mission for a short rundown. After start, use Tasks and map markers for orders, grids, and win/fail criteria.";

// Word-wrap one paragraph to fit listbox row width; returns array of lines.
FAC_missionsGui_wrapParagraph = {
    params ["_text", "_maxChars"];
    if (_text isEqualTo "") exitWith { [""] };
    private _words = _text splitString " ";
    private _lines = [];
    private _line = "";
    private _wi = 0;
    private _wCount = count _words;
    while { _wi < _wCount } do {
        private _word = _words select _wi;
        private _test = if (_line == "") then { _word } else { _line + " " + _word };
        if ((count _test) > _maxChars && { _line != "" }) then {
            _lines pushBack _line;
            _line = _word;
        } else {
            _line = _test;
        };
        _wi = _wi + 1;
    };
    if (_line != "") then { _lines pushBack _line };
    _lines
};

// Marker for FAC_ensureMissionsGui. Line length now follows the description list width.
FAC_missionsGui_descListW = 0;

// Scrollable read-only description (one lbAdd per wrapped line; RscEdit does not scroll when disabled).
FAC_missionsGui_setDescList = {
    params ["_lb", ["_text", ""]];
    disableSerialization;
    lbClear _lb;
    if (_text isEqualTo "") exitWith { _lb lbSetCurSel -1 };
    if (!(_text isEqualType "")) then { _text = str _text };
    private _flat = (_text splitString (toString [13])) joinString "";
    private _nl = toString [10];
    private _boxW = ((ctrlPosition _lb) select 2) - 0.03;
    if (_boxW < 0.2) then { _boxW = 0.2 };
    private _maxChars = ((round (_boxW * 90)) max 24) min 110;
    private _outLines = [];
    private _paras = _flat splitString _nl;
    private _pi = 0;
    private _pCount = count _paras;
    while { _pi < _pCount } do {
        private _para = _paras select _pi;
        if (_para isEqualTo "") then {
            _outLines pushBack "";
        } else {
            private _paraLines = [_para, _maxChars] call FAC_missionsGui_wrapParagraph;
            { _outLines pushBack _x } forEach _paraLines;
        };
        _pi = _pi + 1;
    };
    { _lb lbAdd _x } forEach _outLines;
    if (lbSize _lb > 0) then { _lb lbSetCurSel 0 };
    _lb lbSetCurSel -1;
};

// Remove first line of server brief when it duplicates the mission type already shown in "OpName (Type)" header.
FAC_missionsGui_stripDuplicateBriefHeader = {
    params ["_brief", "_missionTypeLabel", "_missionTypeId"];
    private _nl = toString [10];
    private _lines = _brief splitString _nl;
    if (count _lines == 0) exitWith { _brief };
    private _first = _lines select 0;
    if (_first == "") exitWith { _brief };
    private _firstU = toUpper _first;
    private _labelU = toUpper _missionTypeLabel;
    private _strip = false;
    if (_missionTypeLabel != "" && { _firstU == _labelU }) then {
        _strip = true;
    } else {
        if (_missionTypeId == "MineClearing" && { _firstU find "MINE / EOD CLEARANCE" == 0 }) then {
            _strip = true;
        };
    };
    if (!_strip) exitWith { _brief };
    _lines deleteAt 0;
    while { count _lines > 0 && { (_lines select 0) == "" } } do { _lines deleteAt 0 };
    if (count _lines == 0) exitWith { "" };
    _lines joinString _nl
};

FAC_missionsGui_tabBrowseIdcs = [60131, 60121, 60170, 60171, 60172];
FAC_missionsGui_tabActiveIdcs = [60112, 60113, 60114, 60115, 60130, 60134, 60135, 60136, 60150, 60151, 60152, 60153];
FAC_missionsGui_cardIdc0 = 60180;
FAC_missionsGui_cardMax = 24;
FAC_missionsGui_rulesHtml = "<t size='0.95' color='#9a9aa0'>Global is shared, one at a time. Single is yours, up to three.</t>";

FAC_missionsGui_xml = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = "" };
    _s = _s splitString "&" joinString "&amp;";
    _s = _s splitString "<" joinString "&lt;";
    _s = _s splitString ">" joinString "&gt;";
    _s
};

FAC_missionsGui_plainBlurb = {
    params ["_desc"];
    if !(_desc isEqualType "") then { _desc = "" };
    private _n = count _desc;
    if (_n >= 4) then {
        private _tail = _desc select [_n - 4, 4];
        if (_tail in [" [G]", " [S]"]) then { _desc = _desc select [0, _n - 4] };
    };
    _desc
};

FAC_missionsGui_icon = {
    params ["_id"];
    private _name = switch _id do {
        case "AreaOfOperations": { "map_ca.paa" };
        case "AssetRetrieval": { "box_ca.paa" };
        case "CAS": { "plane_ca.paa" };
        case "Cargo": { "container_ca.paa" };
        case "CASEVAC": { "heal_ca.paa" };
        case "ClearArea": { "rifle_ca.paa" };
        case "CSAR": { "heli_ca.paa" };
        case "EscapeEvasion": { "run_ca.paa" };
        case "GeoGuesser": { "navigate_ca.paa" };
        case "Hostage": { "meet_ca.paa" };
        case "HVT": { "target_ca.paa" };
        case "InterceptConvoy": { "truck_ca.paa" };
        case "Invasion": { "attack_ca.paa" };
        case "MineClearing": { "mine_ca.paa" };
        case "Operation": { "whiteboard_ca.paa" };
        case "PointDefense": { "defend_ca.paa" };
        case "Raid": { "destroy_ca.paa" };
        case "SearchDestroy": { "search_ca.paa" };
        case "TroopExtract": { "getin_ca.paa" };
        case "TroopInsert": { "land_ca.paa" };
        default { "default_ca.paa" };
    };
    "\a3\ui_f\data\igui\cfg\simpleTasks\types\" + _name
};

FAC_missionsGui_browseHost = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith { controlNull };
    private _host = controlNull;
    {
        _x params ["_pageName", "_group"];
        if (_pageName isEqualTo "browse") exitWith { _host = _group };
    } forEach (_d getVariable ["FAC_gui_pages", []]);
    _host
};

FAC_missionsGui_liveBrief = {
    private _operationNameForPlayer = {
        private _uid = getPlayerUID player;
        private _global = missionNamespace getVariable ["FADE_globalMission", []];
        if (
            count _global >= 5 &&
            {
                (_global param [1, objNull]) == player ||
                { (_global param [3, ""]) == _uid }
            }
        ) exitWith { _global param [4, ""] };
        private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
        private _idx = _singleList findIf {
            (_x param [1, objNull]) == player ||
            { (_x param [3, ""]) == _uid }
        };
        if (_idx >= 0) exitWith { (_singleList select _idx) param [4, ""] };
        ""
    };
    private _brief = player getVariable ["FADE_myMissionBrief", ""];
    if !(_brief isEqualType "") exitWith { "" };
    if (count _brief == 0) exitWith { "" };
    private _opName = [] call _operationNameForPlayer;
    if !(_opName isEqualType "") then { _opName = "" };
    if (_opName isEqualTo "") exitWith { _brief };
    private _missionTypeId = player getVariable ["FADE_myMission", ""];
    private _missionTypeLabel = _missionTypeId;
    if (_missionTypeId != "") then {
        private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
        {
            if ((_x select 1) == _missionTypeId) exitWith { _missionTypeLabel = _x select 0 };
        } forEach _list;
    };
    _brief = [_brief, _missionTypeLabel, _missionTypeId] call FAC_missionsGui_stripDuplicateBriefHeader;
    format ["Operation %1 - %2%3%3%4", _opName, _missionTypeLabel, toString [10], _brief]
};

FAC_missionsGui_slotHtml = {
    params ["_title", "_focus", "_by"];
    private _safeTitle = [_title] call FAC_missionsGui_xml;
    private _safeFocus = [_focus] call FAC_missionsGui_xml;
    private _safeBy = ["Started by " + _by] call FAC_missionsGui_xml;
    "<t size='1.05' color='#f4f4f6'>" + _safeTitle + "</t><br/><t size='0.92' color='#b7bcc6'>" + _safeFocus + "</t><br/><t size='0.85' color='#9a9aa0'>" + _safeBy + "</t>"
};

FAC_missionsGui_bindOnce = {
    params ["_ctrl", "_eh", "_code"];
    if (isNull _ctrl) exitWith {};
    if (_ctrl getVariable ["FAC_missionsGui_bound", false]) exitWith {};
    _ctrl setVariable ["FAC_missionsGui_bound", true];
    _ctrl ctrlAddEventHandler [_eh, _code];
};

FAC_missionsGui_onWheel = {
    params ["_ctrl", "_z"];
    // ctrlParent is the dialog. The card list is the controls group stored on each card.
    private _grp = _ctrl getVariable ["FAC_missionsGui_scrollHost", controlNull];
    if (isNull _grp && { (ctrlType _ctrl) == 15 }) then { _grp = _ctrl };
    if (isNull _grp) exitWith {};
    private _cur = ctrlScrollValues _grp;
    if (count _cur < 2) exitWith {};
    private _hScroll = _cur select 1;
    private _v = (_cur select 0) - (_z * 0.12);
    if (_v < 0) then { _v = 0 };
    if (_v > 1) then { _v = 1 };
    _grp ctrlSetScrollValues [_v, _hScroll];
};

FAC_missionsGui_onCardClick = {
    params ["_ctrl"];
    private _id = _ctrl getVariable ["FAC_missionsGui_cardId", ""];
    if (_id isEqualTo "") exitWith {};
    ["selectMission", [_id]] call (missionNamespace getVariable ["FAC_missionsGui_fnc", {}]);
};

FAC_missionsGui_ensureBrowse = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    private _lb = _d displayCtrl 60120;
    if (isNull _lb) then {
        _lb = [_d, controlNull, "FACRscListDark", 60120, 0, 0, 0, 0, ""] call FAC_gui_put;
    };
    if (!isNull _lb) then { _lb ctrlShow false };
    private _orders = _d displayCtrl 60131;
    if (isNull _orders) then {
        _orders = [_d, controlNull, "FACRscFormStructured", 60131, 0, 0, 0.1, 0.04, ""] call FAC_gui_put;
    };
    if (!isNull _orders) then {
        _orders ctrlSetBackgroundColor [0.10, 0.10, 0.12, 1];
        _orders ctrlCommit 0;
    };
    private _start = _d displayCtrl 60121;
    if (isNull _start) then {
        _start = [_d, controlNull, "FACRscPrimaryBtn", 60121, 0, 0, 0.2, 0.04, "Start selected mission"] call FAC_gui_put;
    };
    if (!isNull _start) then {
        _start ctrlSetBackgroundColor (["primary"] call FAC_gui_styleColor);
        _start ctrlCommit 0;
        [_start, "ButtonClick", { ["startMission", []] call (missionNamespace getVariable ["FAC_missionsGui_fnc", {}]) }] call FAC_missionsGui_bindOnce;
    };
    private _filters = [["All", 60170], ["Global", 60171], ["Single", 60172]];
    {
        _x params ["_label", "_idc"];
        private _btn = _d displayCtrl _idc;
        if (isNull _btn) then {
            _btn = [_d, controlNull, "FACRscPrimaryBtn", _idc, 0, 0, 0.1, 0.04, _label] call FAC_gui_put;
        };
        if (!isNull _btn) then {
            [_btn, "ButtonClick", compile format [
                "['setFilter', ['%1']] call (missionNamespace getVariable ['FAC_missionsGui_fnc', {}]);",
                _label
            ]] call FAC_missionsGui_bindOnce;
        };
    } forEach _filters;
};

FAC_missionsGui_syncBrowseChrome = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    private _on = (missionNamespace getVariable ["FAC_missionsGui_tab", "browse"]) isEqualTo "browse";
    {
        private _c = _d displayCtrl _x;
        if (!isNull _c) then { _c ctrlShow _on };
    } forEach [60121, 60131, 60170, 60171, 60172];
    private _lb = _d displayCtrl 60120;
    if (!isNull _lb) then { _lb ctrlShow false };
    private _filter = missionNamespace getVariable ["FAC_missionsGui_filter", "All"];
    {
        _x params ["_idc", "_name"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then { [_c, _filter isEqualTo _name] call FAC_theme_applyTab };
    } forEach [[60170, "All"], [60171, "Global"], [60172, "Single"]];
};

FAC_missionsGui_layoutBrowse = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    private _host = call FAC_missionsGui_browseHost;
    if (isNull _host) exitWith {};
    private _saved = _d getVariable ["FAC_missionsGui_browseRect", []];
    if !(_saved isEqualType [] && { count _saved == 4 }) then {
        _saved = ctrlPosition _host;
        _d setVariable ["FAC_missionsGui_browseRect", _saved];
    };
    _saved params ["_bx", "_by", "_bw", "_bh"];
    private _gap = 0.008;
    private _filterH = 0.042;
    private _btnH = 0.046;
    private _brief = call FAC_missionsGui_liveBrief;
    private _ordersH = if (_brief isEqualTo "") then { 0.046 } else { 0.150 };
    if ((_d getVariable ["FAC_missionsGui_layoutSig", -1]) isEqualTo _ordersH) exitWith {};
    _d setVariable ["FAC_missionsGui_layoutSig", _ordersH];
    private _top = _filterH + _gap + _ordersH + _gap;
    private _hostH = (_bh - _top - _btnH - _gap) max 0.20;
    _host ctrlSetPosition [_bx, _by + _top, _bw, _hostH];
    _host ctrlCommit 0;
    private _btnW = (_bw - (2 * _gap)) / 3;
    {
        _x params ["_idc", "_col"];
        private _c = _d displayCtrl _idc;
        if (!isNull _c) then {
            _c ctrlSetPosition [_bx + _col * (_btnW + _gap), _by, _btnW, _filterH];
            _c ctrlCommit 0;
        };
    } forEach [[60170, 0], [60171, 1], [60172, 2]];
    private _orders = _d displayCtrl 60131;
    if (!isNull _orders) then {
        _orders ctrlSetPosition [_bx, _by + _filterH + _gap, _bw, _ordersH];
        _orders ctrlCommit 0;
    };
    private _start = _d displayCtrl 60121;
    if (!isNull _start) then {
        _start ctrlSetPosition [_bx, _by + _bh - _btnH, _bw, _btnH];
        _start ctrlCommit 0;
    };
};

FAC_missionsGui_paintCards = {
    private _sel = missionNamespace getVariable ["FAC_missionsGui_selectedId", ""];
    {
        _x params ["_bg", "_accent", "_icon", "_text", "_id", "_stream"];
        private _on = _id isEqualTo _sel && { _sel != "" };
        if (!isNull _bg) then {
            _bg ctrlSetBackgroundColor (if (_on) then { [0.20, 0.22, 0.26, 1] } else { [0.11, 0.11, 0.13, 1] });
            _bg ctrlCommit 0;
        };
        if (!isNull _accent) then {
            private _col = if (_stream isEqualTo "Global") then {
                if (_on) then { [0.62, 0.78, 0.92, 1] } else { [0.40, 0.54, 0.66, 1] }
            } else {
                if (_on) then { [0.92, 0.74, 0.46, 1] } else { [0.62, 0.48, 0.30, 1] }
            };
            _accent ctrlSetBackgroundColor _col;
            _accent ctrlCommit 0;
        };
    } forEach (uiNamespace getVariable ["FAC_missionsGui_cardMeta", []]);
};

FAC_missionsGui_destroyCards = {
    {
        _x params ["_bg", "_accent", "_icon", "_text"];
        { if (!isNull _x) then { ctrlDelete _x } } forEach [_bg, _accent, _icon, _text];
    } forEach (uiNamespace getVariable ["FAC_missionsGui_cardMeta", []]);
    uiNamespace setVariable ["FAC_missionsGui_cardMeta", []];
};

FAC_missionsGui_buildCards = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    private _host = call FAC_missionsGui_browseHost;
    if (isNull _host) exitWith {};
    [] call FAC_missionsGui_destroyCards;
    private _filter = missionNamespace getVariable ["FAC_missionsGui_filter", "All"];
    private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
    private _shown = _list select {
        _filter isEqualTo "All" || { (_x param [3, "Single"]) isEqualTo _filter }
    };
    if (count _shown > FAC_missionsGui_cardMax) then {
        diag_log "[FAC] Missions GUI: card count exceeds idc range.";
        _shown = _shown select [0, FAC_missionsGui_cardMax];
    };
    private _sel = missionNamespace getVariable ["FAC_missionsGui_selectedId", ""];
    private _selOk = false;
    { if ((_x select 1) isEqualTo _sel) then { _selOk = true } } forEach _shown;
    if (!_selOk) then {
        _sel = "";
        missionNamespace setVariable ["FAC_missionsGui_selectedId", ""];
    };
    private _lb = _d displayCtrl 60120;
    if (!isNull _lb) then { lbClear _lb };
    private _hp = ctrlPosition _host;
    private _gap = 0.010;
    private _cardH = 0.200;
    private _inner = ((_hp select 2) - 0.036) max 0.40;
    private _cardW = (_inner - _gap) / 2;
    private _iconH = 0.046;
    private _pw = pixelW;
    private _ph = pixelH;
    private _iconW = if (_pw > 0 && { _ph > 0 }) then { _iconH * _pw / _ph } else { 0.026 };
    private _meta = [];
    private _i = 0;
    {
        _x params [["_name", ""], ["_id", ""], ["_desc", ""], ["_stream", "Single"]];
        private _col = _i % 2;
        private _row = floor (_i / 2);
        private _cx = 0.008 + _col * (_cardW + _gap);
        private _cy = 0.008 + _row * (_cardH + _gap);
        private _idc = FAC_missionsGui_cardIdc0 + (_i * 4);
        private _bg = [_d, _host, "FACRscPrimaryBtn", _idc, _cx, _cy, _cardW, _cardH, ""] call FAC_gui_put;
        private _accent = [_d, _host, "RscText", _idc + 1, _cx, _cy, 0.008, _cardH, ""] call FAC_gui_put;
        private _icon = [_d, _host, "FACRscPicture", _idc + 2, _cx + 0.016, _cy + ((_cardH - _iconH) / 2), _iconW, _iconH, ""] call FAC_gui_put;
        private _text = [_d, _host, "FACRscFormStructured", _idc + 3, _cx + 0.024 + _iconW, _cy + 0.010, (_cardW - _iconW - 0.040) max 0.12, _cardH - 0.018, ""] call FAC_gui_put;
        if (!isNull _icon) then {
            _icon ctrlSetText ([_id] call FAC_missionsGui_icon);
            _icon ctrlSetTextColor [0.92, 0.93, 0.95, 1];
            _icon ctrlSetBackgroundColor [0, 0, 0, 0];
            _icon ctrlCommit 0;
        };
        if (!isNull _text) then {
            _text ctrlSetBackgroundColor [0, 0, 0, 0];
            private _kind = if (_stream isEqualTo "Global") then { "Global" } else { "Single" };
            private _kindCol = if (_stream isEqualTo "Global") then { "#8eb4d4" } else { "#d4b48e" };
            private _blurb = [_desc] call FAC_missionsGui_plainBlurb;
            private _html = "<t size='1.2' color='#f4f4f6'>" + ([_name] call FAC_missionsGui_xml) + "</t><br/><t size='0.82' color='" + _kindCol + "'>" + _kind + "</t><br/><t size='0.92' color='#b7bcc6'>" + ([_blurb] call FAC_missionsGui_xml) + "</t>";
            _text ctrlSetStructuredText parseText _html;
            _text ctrlCommit 0;
        };
        {
            if (!isNull _x) then {
                _x setVariable ["FAC_missionsGui_cardId", _id];
                _x setVariable ["FAC_missionsGui_scrollHost", _host];
                _x ctrlAddEventHandler ["MouseButtonDown", FAC_missionsGui_onCardClick];
                if (_x isEqualTo _bg) then {
                    _x ctrlAddEventHandler ["ButtonClick", FAC_missionsGui_onCardClick];
                };
                _x ctrlAddEventHandler ["MouseZChanged", FAC_missionsGui_onWheel];
            };
        } forEach [_bg, _accent, _icon, _text];
        _meta pushBack [_bg, _accent, _icon, _text, _id, _stream];
        if (!isNull _lb) then {
            private _idx = _lb lbAdd _name;
            _lb lbSetData [_idx, _id];
            if (_id isEqualTo _sel) then { _lb lbSetCurSel _idx };
        };
        _i = _i + 1;
    } forEach _shown;
    if (!isNull _lb && { _sel isEqualTo "" }) then { _lb lbSetCurSel -1 };
    uiNamespace setVariable ["FAC_missionsGui_cardMeta", _meta];
    private _rowsN = ceil ((count _shown) / 2);
    if (_rowsN < 1) then { _rowsN = 1 };
    private _bottom = 0.008 + _rowsN * (_cardH + _gap);
    private _sp = _d displayCtrl 60179;
    if (isNull _sp) then {
        _sp = [_d, _host, "RscText", 60179, 0, _bottom, 0.01, 0.01, ""] call FAC_gui_put;
        _host ctrlAddEventHandler ["MouseZChanged", FAC_missionsGui_onWheel];
    } else {
        _sp ctrlSetPosition [0, _bottom, 0.01, 0.01];
        _sp ctrlCommit 0;
    };
    _host ctrlSetScrollValues [0, 0];
    [] call FAC_missionsGui_paintCards;
};

FAC_missionsGui_syncTabs = {
    private _d = findDisplay 60002;
    if (isNull _d) exitWith {};
    private _tab = missionNamespace getVariable ["FAC_missionsGui_tab", "browse"];
    if (!isNull (_d displayCtrl 59900)) exitWith {
        {
            private _c = _d displayCtrl _x;
            if (!isNull _c) then { _c ctrlShow true };
        } forEach [59900, 59901, 59902, 59903, 59904, 59905, 60160, 60161];
        [_d, _tab] call FAC_gui_showPage;
        [] call FAC_missionsGui_syncBrowseChrome;
    };
    {
        private _c = _d displayCtrl _x;
        if (!isNull _c) then { _c ctrlShow (_tab == "browse") };
    } forEach FAC_missionsGui_tabBrowseIdcs;
    {
        private _c = _d displayCtrl _x;
        if (!isNull _c) then { _c ctrlShow (_tab == "active") };
    } forEach FAC_missionsGui_tabActiveIdcs;
    { private _c = _d displayCtrl _x; if (!isNull _c) then { _c ctrlShow true } } forEach [60101, 60160, 60161, 60141, 60142];
    [_d displayCtrl 60160, _tab == "browse"] call FAC_theme_applyTab;
    [_d displayCtrl 60161, _tab == "active"] call FAC_theme_applyTab;
    [] call FAC_missionsGui_syncBrowseChrome;
};

FADE_receiveCopilotState = {
    // Kept for compatibility with server RPC; copilot controls were removed from this dialog.
    params [["_hasCopilot", false]];
};

FAC_missionsGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60002;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {
        case "open": {
            if !(["FAC_playerCanUseMissionsGui"] call FAC_lobbyParams_callAccess) exitWith {
                systemChat "Missions GUI access denied by lobby settings.";
            };
            if (!isNil "FAC_ensureMissionsGui_overlay") then { call FAC_ensureMissionsGui_overlay };
            if (!createDialog "RscDisplayMissions") then {
                systemChat "MISSIONS GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            disableSerialization;
            private _display = findDisplay 60002;
            if (isNull _display) exitWith {};
            [_display, FAC_gui_spec_missions] call FAC_gui_build;
            if (!isNil "FAC_ensureMissionsGui_overlay") then { call FAC_ensureMissionsGui_overlay };
            if (!isNil "FAC_escapeEvasionPickGui_fnc_destroyOverlay" && { !isNil "FAC_missionPickOverlay_destroy" }) then {
                [] call FAC_escapeEvasionPickGui_fnc_destroyOverlay;
            };
            uinamespace setVariable ["FAC_missionsGui_fnc", FAC_missionsGui_fnc];
            missionNamespace setVariable ["FAC_missions_abortPendingTime", -99];
            missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];

            if (isNil { missionNamespace getVariable "FAC_missionsGui_filter" }) then {
                missionNamespace setVariable ["FAC_missionsGui_filter", "All"];
            };
            missionNamespace setVariable ["FAC_missionsGui_selectedId", ""];
            missionNamespace setVariable ["FAC_missionsGui_tab", "browse"];
            [] call FAC_missionsGui_ensureBrowse;
            [] call FAC_missionsGui_layoutBrowse;
            [] call FAC_missionsGui_buildCards;
            ["refreshStatus", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
            [] call FAC_missionsGui_syncTabs;
        };
        case "setTab": {
            if (isNull _display) exitWith {};
            private _tab = _params param [0, "browse"];
            if !(_tab in ["browse", "active"]) then { _tab = "browse" };
            missionNamespace setVariable ["FAC_missionsGui_tab", _tab];
            [] call FAC_missionsGui_syncTabs;
            if (_tab == "active") then { ["refreshStatus", []] call FAC_missionsGui_fnc };
        };
        case "headerRefresh": {
            ["refreshStatus", []] call FAC_missionsGui_fnc;
            [] call FAC_missionsGui_syncTabs;
        };
        case "abortSlot": {
            if (isNull _display) exitWith {};
            private _slot = toUpper ((_params param [0, ""]) + "");
            if !(_slot in ["G1", "S1", "S2", "S3"]) exitWith {};
            private _btnIdc = switch _slot do {
                case "G1": { 60150 };
                case "S1": { 60151 };
                case "S2": { 60152 };
                default { 60153 };
            };
            private _btn = _display displayCtrl _btnIdc;
            private _pending = missionNamespace getVariable ["FAC_missions_abortSlotPending", ["", -99]];
            private _pendingSlot = _pending param [0, ""];
            private _pendingTime = _pending param [1, -99];
            if (_pendingSlot != _slot || { time - _pendingTime > 3 }) then {
                missionNamespace setVariable ["FAC_missions_abortSlotPending", [_slot, time]];
                _btn ctrlSetText ("CONFIRM " + _slot + "?");
                _btn ctrlSetTextColor [1, 0.35, 0.35, 1];
                [] spawn {
                    sleep 3;
                    private _st = missionNamespace getVariable ["FAC_missions_abortSlotPending", ["", -99]];
                    if ((_st param [0, ""]) != "") then {
                        missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];
                        if (!isNull (findDisplay 60002)) then {
                            { ((findDisplay 60002) displayCtrl _x) ctrlSetTextColor [1, 1, 1, 1] } forEach [60150, 60151, 60152, 60153];
                            ((findDisplay 60002) displayCtrl 60150) ctrlSetText "Abort G1";
                            ((findDisplay 60002) displayCtrl 60151) ctrlSetText "Abort S1";
                            ((findDisplay 60002) displayCtrl 60152) ctrlSetText "Abort S2";
                            ((findDisplay 60002) displayCtrl 60153) ctrlSetText "Abort S3";
                        };
                    };
                };
            } else {
                missionNamespace setVariable ["FAC_missions_abortSlotPending", ["", -99]];
                { ((findDisplay 60002) displayCtrl _x) ctrlSetTextColor [1, 1, 1, 1] } forEach [60150, 60151, 60152, 60153];
                ((findDisplay 60002) displayCtrl 60150) ctrlSetText "Abort G1";
                ((findDisplay 60002) displayCtrl 60151) ctrlSetText "Abort S1";
                ((findDisplay 60002) displayCtrl 60152) ctrlSetText "Abort S2";
                ((findDisplay 60002) displayCtrl 60153) ctrlSetText "Abort S3";
                [_slot, player] remoteExec ["FADE_abortMissionSlot", 2];
                [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
            };
        };
        case "startMission": {
            if (isNull _display) exitWith {};
            private _lb = _display displayCtrl 60120;
            private _idx = lbCurSel _lb;
            if (_idx < 0) then { systemChat "SELECT MISSION."; return };
            private _missionType = _lb lbData _idx;
            if (_missionType == "EscapeEvasion") exitWith {
                if (isNil "FAC_escapeEvasionPickGui_fnc") exitWith { systemChat "ESCAPE & EVASION UI not loaded."; };
                ["open", []] call FAC_escapeEvasionPickGui_fnc;
            };
            if (_missionType == "GeoGuesser") exitWith {
                if (isNil "FAC_geoGuesserPickGui_fnc") exitWith { systemChat "GEO-GUESSER UI not loaded."; };
                ["open", []] call FAC_geoGuesserPickGui_fnc;
            };
            if (_missionType == "TroopInsert") exitWith {
                if (isNil "FAC_troopInsertPickGui_fnc") exitWith { systemChat "TROOP TRANSPORT UI not loaded."; };
                uinamespace setVariable ["FAC_troopTransport_mapAnchor", []];
                uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                ["open", [_missionType]] call FAC_troopInsertPickGui_fnc;
            };
            if (_missionType == "TroopExtract") exitWith {
                if (isNil "FAC_troopInsertPickGui_fnc") exitWith { systemChat "TROOP TRANSPORT UI not loaded."; };
                uinamespace setVariable ["FAC_troopTransport_mapAnchor", []];
                uinamespace setVariable ["FAC_troopInsert_lzAnchor", nil];
                ["open", [_missionType]] call FAC_troopInsertPickGui_fnc;
            };
            if (_missionType == "PointDefense") exitWith {
                if (isNil "FAC_pointDefensePickGui_fnc") exitWith { systemChat "POINT DEFENSE UI not loaded."; };
                ["open", []] call FAC_pointDefensePickGui_fnc;
            };
            if (isNil "FAC_missionLocationPickGui_fnc") exitWith { systemChat "MISSION: location picker not loaded."; };
            ["open", [_missionType]] call FAC_missionLocationPickGui_fnc;
        };
        case "refreshStatus": {
            if (isNull _display) exitWith {};
            private _missionList = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _displayName = {
                params ["_typeId"];
                private _dn = _typeId;
                { if ((_x select 1) == _typeId) exitWith { _dn = _x select 0 } } forEach _missionList;
                _dn
            };
            private _entryTitle = {
                params ["_entry"];
                private _type = _entry param [0, ""];
                private _operationName = _entry param [4, ""];
                // If an operation name is provided, prefer "Operation <name>" as the title.
                if (_operationName isEqualType "" && { _operationName != "" }) exitWith { format ["Operation %1", _operationName] };
                [_type] call _displayName
            };
            private _ownerStr = {
                params ["_o"];
                if (!isNull _o) then { name _o } else { "?" }
            };
            private _slotFocusLine = {
                params ["_entry"];
                if (count _entry < 3) exitWith { "Focus: see Tasks / markers." };
                private _mType = _entry param [0, ""];
                private _pos = _entry param [2, []];
                if (_mType == "InterceptConvoy") exitWith { "Start marker, end marker, and the route line show the convoy path." };
                if (_mType == "Operation") exitWith { "AO: multiple zones  -  capture rules in Tasks." };
                if (_mType == "PointDefense") exitWith { "Hold: 250 m defend zone — timer starts when players enter." };
                if (_pos isEqualType [] && { count _pos >= 2 } && { !(_pos isEqualTo [0, 0, 0]) }) exitWith {
                    "Grid " + (mapGridPosition _pos)
                };
                "Focus: see Tasks / markers."
            };
            private _slotGlobal = _display displayCtrl 60130;
            if (!isNull _slotGlobal) then {
                if (count _global >= 2) then {
                    private _title = [_global] call _entryTitle;
                    private _owner = _global select 1;
                    private _oStr = [_owner] call _ownerStr;
                    private _focus = [_global] call _slotFocusLine;
                    _slotGlobal ctrlSetStructuredText parseText ([_title, _focus, _oStr] call FAC_missionsGui_slotHtml);
                } else {
                    _slotGlobal ctrlSetStructuredText parseText "<t color='#9a9aa0'>Slot free.</t>";
                };
            };
            private _singleIdcs = [60134, 60135, 60136];
            {
                private _c = _display displayCtrl _x;
                private _entry = _singleList param [_forEachIndex, []];
                if (!isNull _c) then {
                    if (count _entry >= 2) then {
                        _entry params ["", "_o"];
                        private _n = [_entry] call _entryTitle;
                        private _oStr = [_o] call _ownerStr;
                        private _focus = [_entry] call _slotFocusLine;
                        _c ctrlSetStructuredText parseText ([_n, _focus, _oStr] call FAC_missionsGui_slotHtml);
                    } else {
                        _c ctrlSetStructuredText parseText "<t color='#9a9aa0'>Slot free.</t>";
                    };
                };
            } forEach _singleIdcs;
            private _gAbort = _display displayCtrl 60150;
            if (!isNull _gAbort) then { _gAbort ctrlEnable (count _global >= 2) };
            {
                private _btn = _display displayCtrl _x;
                if (!isNull _btn) then {
                    _btn ctrlEnable (count _singleList > _forEachIndex);
                };
            } forEach [60151, 60152, 60153];
            ["refreshDescription", []] call FAC_missionsGui_fnc;
            ["updateButtons", []] call FAC_missionsGui_fnc;
            [] call FAC_missionsGui_syncTabs;
        };
        case "updateButtons": {
            if (isNull _display) exitWith {};
            private _missionLb = _display displayCtrl 60120;
            private _startBtn = _display displayCtrl 60121;
            private _global = missionNamespace getVariable ["FADE_globalMission", []];
            private _singleList = missionNamespace getVariable ["FADE_singleMissions", []];
            private _uid = getPlayerUID player;
            private _playerHasMission = (
                count _global >= 2 && {
                    (_global select 1 == player) || { (_global param [3, ""]) == _uid }
                }
            ) || {
                {
                    ((_x param [1, objNull]) == player) || { (_x param [3, ""]) == _uid }
                } count _singleList > 0
            };
            if (isNull _missionLb || { isNull _startBtn }) exitWith {};
            private _idx = lbCurSel _missionLb;
            private _canStart = lbSize _missionLb > 0 && { _idx >= 0 } && { !_playerHasMission };
            if (_canStart && { _idx >= 0 }) then {
                private _missionId = _missionLb lbData _idx;
                private _list = missionNamespace getVariable ["FAC_missionsGui_missionList", []];
                private _stream = "Single";
                { if ((_x select 1) == _missionId) exitWith { _stream = _x select 3 } } forEach _list;
                if (_stream == "Global" && { count _global >= 1 }) then { _canStart = false };
                if (_stream == "Single" && { count _singleList >= 3 }) then { _canStart = false };
            };
            _startBtn ctrlEnable _canStart;
        };
        case "setFilter": {
            if (isNull _display) exitWith {};
            private _filter = _params param [0, "All"];
            if !(_filter in ["All", "Global", "Single"]) then { _filter = "All" };
            missionNamespace setVariable ["FAC_missionsGui_filter", _filter];
            [] call FAC_missionsGui_buildCards;
            [] call FAC_missionsGui_syncBrowseChrome;
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "selectMission": {
            if (isNull _display) exitWith {};
            private _id = _params param [0, ""];
            missionNamespace setVariable ["FAC_missionsGui_selectedId", _id];
            [] call FAC_missionsGui_paintCards;
            private _lb = _display displayCtrl 60120;
            if (!isNull _lb) then {
                private _found = -1;
                for "_i" from 0 to ((lbSize _lb) - 1) do {
                    if ((_lb lbData _i) isEqualTo _id) then { _found = _i };
                };
                _lb lbSetCurSel _found;
            };
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        case "missionSelChanged": {
            ["updateButtons", []] call FAC_missionsGui_fnc;
        };
        // Live brief for the local player, or the short rules line when none is running.
        case "refreshDescription": {
            if (isNull _display) exitWith {};
            [] call FAC_missionsGui_layoutBrowse;
            private _orders = _display displayCtrl 60131;
            if (isNull _orders) exitWith {};
            private _brief = call FAC_missionsGui_liveBrief;
            if (_brief isEqualTo "") then {
                _orders ctrlSetStructuredText parseText FAC_missionsGui_rulesHtml;
            } else {
                private _body = [_brief] call FAC_missionsGui_xml;
                _body = (_body splitString (toString [13])) joinString "";
                _body = (_body splitString (toString [10])) joinString "<br/>";
                _orders ctrlSetStructuredText parseText ("<t size='1.08' color='#f4f4f6'>Current orders</t><br/><t size='0.92' color='#d8d8dc'>" + _body + "</t>");
            };
        };
    };
};
missionNamespace setVariable ["FAC_missionsGui_fnc", FAC_missionsGui_fnc];
missionNamespace setVariable ["FAC_missionsGui_syncTabs", FAC_missionsGui_syncTabs];
