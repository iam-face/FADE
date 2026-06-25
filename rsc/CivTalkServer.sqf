// =============================================================================
// CivTalkServer.sqf  -  server: ambient civilian dialogue sessions (MP authority)
// =============================================================================
// Compiled on server from initServer.sqf. Clients use CivTalkGui + addAction.

if (!isServer) exitWith {};

if (isNil "FADE_civTalk_sessions") then { FADE_civTalk_sessions = createHashMap };
if (isNil "FADE_civTalk_cooldowns") then { FADE_civTalk_cooldowns = createHashMap };

FADE_civTalk_resolveCiv = {
    params [["_netId", ""]];
    if (!(_netId isEqualType "") || { _netId == "" }) exitWith { objNull };
    private _u = [_netId] call FADE_entityRegistry_resolveNetId;
    if (isNull _u) then {
        _u = _netId call BIS_fnc_objectFromNetId;
    };
    if (isNull _u || {!alive _u}) exitWith { objNull };
    if !(_u getVariable ["FADE_ambientCiv", false] || {_u getVariable ["FADE_baseNpcTalk", false]}) exitWith { objNull };
    _u
};

FADE_civTalk_bearingWord = {
    params ["_deg"];
    _deg = (_deg + 360) % 360;
    private _sectors = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    _sectors select ((round (_deg / 22.5)) mod 16)
};

// One optional flavour line for replies (time-of-day + nearest named location); folded into same reply string.
FADE_civTalk_contextLines = {
    params [["_civ", objNull]];
    if (isNull _civ || {!alive _civ}) exitWith { "" };
    private _bits = [];
    private _dt = dayTime;
    if (_dt >= 19 || _dt < 5) then {
        _bits pushBack (selectRandom (missionNamespace getVariable ["FADE_civTalkCtxNight", ["It is hard to see at night."]]));
    } else {
        if (_dt < 12) then {
            _bits pushBack (selectRandom (missionNamespace getVariable ["FADE_civTalkCtxMorning", ["The morning is quiet."]]));
        } else {
            _bits pushBack (selectRandom (missionNamespace getVariable ["FADE_civTalkCtxAfternoon", ["Heat shimmers on the road."]]));
        };
    };
    private _pos = getPosATL _civ;
    private _locs = nearestLocations [_pos, ["NameCity", "NameCityCapital", "NameVillage", "NameLocal"], 4000];
    if (count _locs > 0) then {
        private _ln = text (_locs select 0);
        if (_ln != "") then {
            private _fmt = selectRandom (missionNamespace getVariable ["FADE_civTalkCtxNearFmt", ["Not far from %1."]]);
            _bits pushBack format [_fmt, _ln];
        };
    };
    if (_bits isEqualTo []) exitWith { "" };
    selectRandom _bits
};

// Arrest fallout: mark ambient civs in radius as permanently uncooperative (no intel paths).
FADE_civTalk_markNearbyUncooperative = {
    params [["_centerCiv", objNull], ["_radius", 500]];
    if (isNull _centerCiv || {!alive _centerCiv}) exitWith {};
    private _near = _centerCiv nearEntities [["Man"], _radius max 0];
    {
        if (alive _x && {_x getVariable ["FADE_ambientCiv", false]}) then {
            _x setVariable ["FADE_civTalkForcedUncooperative", true, true];
        };
    } forEach _near;
};

// Player stands _sep m in front of civ (toward current player); civ only turns. Returns [playerATL, playerDir, civDir].
FADE_civTalk_computeFaceToFace = {
    params ["_civ", "_player"];
    private _c = +getPosATL _civ;
    private _p = +getPosATL _player;
    private _dirToP = _c getDir _p;
    private _sep = missionNamespace getVariable ["FADE_civTalkFaceSeparationM", 3];
    private _newP = _c getPos [_sep, _dirToP];
    _newP set [2, _c select 2];
    // Max search was 8m  -  safe pos could land the player far from the civ; keep nudge within ~1m of intended spot only.
    private _sp = [[_newP, 0, 1, 2, 0, 0.35, 0, [], _newP], _newP] call FADE_findSafePosArray;
    // findSafePos can rarely return a far fallback; keep the snap within a few metres of the intended face-to-face spot.
    if (_sp isEqualType [] && { count _sp >= 2 }) then {
        private _d2 = _newP distance2D [_sp select 0, _sp select 1];
        if (_d2 <= 4) then {
            _newP set [0, _sp select 0];
            _newP set [1, _sp select 1];
        };
    };
    private _pDir = [_newP, _c] call BIS_fnc_dirTo;
    private _cDir = [_c, _newP] call BIS_fnc_dirTo;
    [_newP, _pDir, _cDir]
};

FADE_civTalk_clearCivMoveLock = {
    params [["_civ", objNull]];
    if (isNull _civ || {!alive _civ}) exitWith {};
    if (_civ getVariable ["FADE_baseNpcTalk", false]) exitWith {};
    _civ enableAI "MOVE";
    if (_civ getVariable ["ace_captives_isHandcuffed", false]) exitWith {};
    _civ switchMove "";
};

// After _delay s, snap civ back to idle pose (interrupts long anims).
FADE_civTalk_serverCivReturnIdleDelayed = {
    params [["_netId", ""], ["_delay", 5]];
    [_netId, _delay] spawn {
        params ["_netId", "_delay"];
        sleep _delay;
        if (!isServer) exitWith {};
        private _civ = [_netId] call FADE_civTalk_resolveCiv;
        if (isNull _civ) exitWith {};
        if (_civ getVariable ["ace_captives_isHandcuffed", false]) exitWith {};
        _civ switchMove "";
        private _idle = missionNamespace getVariable ["FADE_civTalkAnimCivIdle", "Acts_CivilIdle_2"];
        _civ switchMove _idle;
    };
};

// -----------------------------------------------------------------------------
FADE_civTalk_serverCivAnim = {
    if (!isServer) exitWith {};
    params [["_netId", ""], ["_phase", "idle"]];
    private _civ = [_netId] call FADE_civTalk_resolveCiv;
    if (isNull _civ) exitWith {};
    _civ switchMove "";
    if ((toLower _phase) == "clear") exitWith {};
    private _idle = missionNamespace getVariable ["FADE_civTalkAnimCivIdle", "Acts_CivilIdle_2"];
    private _intel = missionNamespace getVariable ["FADE_civTalkAnimCivIntel", "Acts_Pointing_Right"];
    switch (toLower _phase) do {
        case "idle": { _civ switchMove _idle };
        case "talk": { _civ switchMove _idle };
        case "intel": { _civ switchMove _intel };
        default { _civ switchMove _idle };
    };
};

// -----------------------------------------------------------------------------
FADE_civTalk_start = {
    if (!isServer) exitWith {};
    params [["_player", objNull], ["_netId", ""]];
    if (isNull _player || {!isPlayer _player}) exitWith {};
    private _civ = [_netId] call FADE_civTalk_resolveCiv;
    if (isNull _civ) exitWith {
        "No one to talk to." remoteExec ["systemChat", _player];
    };
    private _isBaseNpc = _civ getVariable ["FADE_baseNpcTalk", false];
    private _maxD = missionNamespace getVariable ["FADE_civTalkMaxDistM", 6];
    if (_player distance _civ > _maxD) exitWith {
        "Too far away." remoteExec ["systemChat", _player];
    };
    if (!_isBaseNpc) then {
        if !(missionNamespace getVariable ["FADE_civiliansEnabled", true]) exitWith {
            "There is no one to talk to." remoteExec ["systemChat", _player];
        };
        private _cdKey = format ["%1_%2", getPlayerUID _player, _netId];
        private _cdT = missionNamespace getVariable ["FADE_civTalkCooldownS", 45];
        private _last = FADE_civTalk_cooldowns getOrDefault [_cdKey, -1e12];
        if ((time - _last) < _cdT) exitWith {
            "They are not interested in talking right now." remoteExec ["systemChat", _player];
        };
    };
    private _langOk = if (_isBaseNpc) then {
        true
    } else {
        !(missionNamespace getVariable ["FADE_civTalkInterpretersOnly", false])
            || { _player getVariable ["FADE_civInterpreter", false] }
    };
    private _uid = getPlayerUID _player;
    if (!isNil { FADE_civTalk_sessions get _uid }) then {
        private _prevId = (FADE_civTalk_sessions get _uid) param [0, ""];
        private _prevCiv = [_prevId] call FADE_civTalk_resolveCiv;
        if (!isNull _prevCiv) then { [_prevCiv] call FADE_civTalk_clearCivMoveLock };
        FADE_civTalk_sessions deleteAt _uid;
    };
    private _positive = true;
    if (!_isBaseNpc) then {
        private _forcedUncoop = _civ getVariable ["FADE_civTalkForcedUncooperative", false];
        private _pPos = missionNamespace getVariable ["FADE_civTalkPositiveChance", 0.5];
        _pPos = (_pPos max 0) min 1;
        _positive = _langOk && {!_forcedUncoop} && { random 1 < _pPos };
    };
    private _stance = [_civ, _player] call FADE_civTalk_computeFaceToFace;
    _stance params ["_playerAtl", "_playerDir", "_civDir"];
    // Same snap as client cutscene  -  without this, server still has pre-dialogue player pos and
    // FADE_civTalk_topic's distance check fails (client moved locally; authority stayed "far").
    _player setPosATL _playerAtl;
    _player setDir _playerDir;
    _civ disableAI "MOVE";
    doStop _civ;
    _civ setDir _civDir;
    [_netId, "idle"] call FADE_civTalk_serverCivAnim;
    // [netId, positive, time, langOk, greetingUsed, carUsed, opforClicks, opforFirstWasIntel, rumoursUsed, arrestUsed, sessionKind]
    if (_isBaseNpc) then {
        FADE_civTalk_sessions set [_uid, [_netId, true, time, true, false, false, 0, false, false, false, "baseNpc"]];
        [_playerAtl, _playerDir, true, _netId, true, "baseNpc"] remoteExec ["FADE_civTalk_clientBeginCutscene", _player];
    } else {
        private _cdKey = format ["%1_%2", getPlayerUID _player, _netId];
        FADE_civTalk_cooldowns set [_cdKey, time];
        FADE_civTalk_sessions set [_uid, [_netId, _positive, time, _langOk, false, false, 0, false, false, false, "ambient"]];
        [_playerAtl, _playerDir, _positive, _netId, _langOk, "ambient"] remoteExec ["FADE_civTalk_clientBeginCutscene", _player];
    };
};

// [carEn, opforEn, opforBtnText, rumoursEn, arrestEn] for radial "Talk to..." + apprehend
FADE_civTalk_uiFromSession = {
    params ["_sess", "_langOk"];
    private _positive = _sess select 1;
    private _cU = _sess select 5;
    private _oC = _sess select 6;
    private _oI = _sess select 7;
    private _rU = _sess param [8, false];
    private _aU = _sess param [9, false];
    private _def = missionNamespace getVariable ["FADE_civTalkBtnOpforDefault", "Seen any OPFOR?"];
    private _follow = missionNamespace getVariable ["FADE_civTalkOpforFollowupButtonText", "Are you sure you didn't see anything?"];
    private _cEn = !_cU;
    private _oEn = _oC < 2;
    private _oTxt = _def;
    if (_langOk && {_positive} && {_oC >= 1} && {!_oI} && {_oEn}) then { _oTxt = _follow };
    private _rumoursEn = !_rU;
    private _arrestEn = !_aU;
    [_cEn, _oEn, _oTxt, _rumoursEn, _arrestEn]
};

// -----------------------------------------------------------------------------
FADE_civTalk_topic = {
    if (!isServer) exitWith {};
    params [["_player", objNull], ["_topic", ""]];
    if (isNull _player || {!isPlayer _player}) exitWith {};
    private _uid = getPlayerUID _player;
    private _sess = FADE_civTalk_sessions getOrDefault [_uid, []];
    if (count _sess < 2) exitWith {};
    _sess = +_sess;
    // Session has 11 fields (index 10 = sessionKind). Earlier resize 10 stripped it,
    // forcing every base NPC topic into the ambient fall-through (default reply "...").
    if (count _sess < 11) then { _sess resize 11 };
    if (isNil {_sess select 4}) then { _sess set [4, false] };
    if (isNil {_sess select 5}) then { _sess set [5, false] };
    if (isNil {_sess select 6}) then { _sess set [6, 0] };
    if (isNil {_sess select 7}) then { _sess set [7, false] };
    if (isNil {_sess select 8}) then { _sess set [8, false] };
    if (isNil {_sess select 9}) then { _sess set [9, false] };
    if (isNil {_sess select 10}) then { _sess set [10, "ambient"] };
    _sess params ["_netId", "_positive"];
    private _langOk = _sess param [3, true];
    private _sessionKind = _sess param [10, "ambient"];
    private _greetingUsed = _sess select 4;
    private _carUsed = _sess select 5;
    private _opforClicks = _sess select 6;
    private _topicL = toLower _topic;
    private _civ = [_netId] call FADE_civTalk_resolveCiv;
    if (isNull _civ) exitWith {
        FADE_civTalk_sessions deleteAt _uid;
        ["They left.", []] remoteExec ["FADE_civTalk_clientSetReply", _player];
    };

    if (_sessionKind isEqualTo "baseNpc") exitWith {
        if !(_topicL in ["base_npc_hello", "base_npc_mission", "base_npc_goodbye"]) exitWith {};
        private _pool = missionNamespace getVariable ["FADE_baseNpcTalkReplies", []];
        if !(_pool isEqualType []) then { _pool = [] };
        if (_pool isEqualTo []) then { _pool = ["..."] };
        private _reply = selectRandom _pool;
        private _uiStub = [true, false, "", false, false];
        private _autoClose = _topicL isEqualTo "base_npc_goodbye";
        FADE_civTalk_sessions set [_uid, _sess];
        if (_autoClose) then {
            [_reply, _uiStub, true] remoteExec ["FADE_civTalk_clientSetReply", _player];
        } else {
            [_reply, _uiStub] remoteExec ["FADE_civTalk_clientSetReply", _player];
        };
    };

    private _civDisplayName = {
        params ["_u"];
        private _n = name _u;
        if (_n == "") then { _n = "This person" };
        _n
    };

    if (_topicL == "greeting" && {_greetingUsed}) exitWith {};
    if (_topicL == "car" && {_carUsed}) exitWith {};
    if (_topicL == "opfor" && {_opforClicks >= 2}) exitWith {};
    if (_topicL == "rumours" && {_sess select 8}) exitWith {};
    if (_topicL == "arrest" && {_sess select 9}) exitWith {};

    private _finish = {
        params ["_reply", "_sess", "_uid", "_player", "_netId", "_lineIntel", "_langOk"];
        FADE_civTalk_sessions set [_uid, _sess];
        private _ui = [_sess, _langOk] call FADE_civTalk_uiFromSession;
        if (_lineIntel) then {
            [_netId, "intel"] call FADE_civTalk_serverCivAnim;
            private _iw = missionNamespace getVariable ["FADE_civTalkIntelPoseSec", 4.5];
            [_netId, _iw max 1] call FADE_civTalk_serverCivReturnIdleDelayed;
        };
        [_reply, _ui] remoteExec ["FADE_civTalk_clientSetReply", _player];
        private _logDiary = missionNamespace getVariable ["FADE_civTalkIntelDiary", true];
        if (_logDiary && {_lineIntel} && {_reply != ""} && {!isNull _civ} && {alive _civ}) then {
            private _nm = [_civ] call _civDisplayName;
            private _kind = switch (_topicL) do {
                case "opfor": {"OPFOR sighting"};
                case "car": {"Vehicle tip"};
                default {"HUMINT"};
            };
            private _when = format ["Mission +%1 min", floor (time / 60) max 0];
            [_nm, _when, _reply, _kind] remoteExec ["FADE_civTalk_clientAppendIntelDiary", _player];
        };
    };

    if (_topicL in ["gesture_away", "gesture_stay", "gesture_down"]) exitWith {
        private _interp = _player getVariable ["FADE_civInterpreter", false];
        private _pComply = if (_interp) then { 1 } else { 0.5 };
        private _complies = random 1 < _pComply;
        private _nm = [_civ] call _civDisplayName;
        private _noFmt = missionNamespace getVariable ["FADE_civTalkGestureNoUnderstandFmt", "%1 does not understand you."];
        private _noUnderstand = format [_noFmt, _nm];
        if (!_complies) exitWith {
            [_noUnderstand, _sess, _uid, _player, _netId, false, _langOk] call _finish;
        };
        private _reply = "";
        private _lineIntel = false;
        private _restoreFn = missionNamespace getVariable ["FADE_civ_restoreAmbientFootPatrol", nil];
        switch _topicL do {
            case "gesture_away": {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkGestureAway", ["Fine, I am leaving."]]);
                if (!isNil "_restoreFn") then { [_civ] call _restoreFn };
                [_reply, _sess, _uid, _player, _netId, false, _langOk] call _finish;
                [_player, "Acts_Ambient_Dismissing"] remoteExec ["FADE_civTalk_clientPlayGestureAnimOnUnit", _player];
                [] remoteExec ["FADE_civTalk_clientCloseCivTalkForGesture", _player];
            };
            case "gesture_stay": {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkGestureStay", ["I will stay."]]);
                private _grp = group _civ;
                if (!isNull _grp) then {
                    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0] };
                    _grp setBehaviour "SAFE";
                };
                _civ setVariable ["FADE_civTalkHoldAfterTalk", true, false];
                [_player, "Acts_Ambient_Disagreeing_with_pointing"] remoteExec ["FADE_civTalk_clientPlayGestureAnimOnUnit", _player];
                [_reply, _sess, _uid, _player, _netId, false, _langOk] call _finish;
            };
            case "gesture_down": {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkGestureDown", ["I am getting down!"]]);
                [_player, "Acts_Ambient_Aggressive"] remoteExec ["FADE_civTalk_clientPlayGestureAnimOnUnit", _player];
                private _delay = 1 + random 2;
                [_civ, _delay] spawn {
                    params ["_u", "_delay"];
                    sleep _delay;
                    if (isNull _u || {!alive _u}) exitWith {};
                    if (_u getVariable ["ace_captives_isHandcuffed", false]) exitWith {};
                    if (local _u) then {
                        _u switchMove "";
                        _u switchMove "Acts_CivilHiding_1";
                    };
                };
                [_reply, _sess, _uid, _player, _netId, false, _langOk] call _finish;
            };
        };
    };

    if (!_langOk) exitWith {
        private _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkNoLangReplies", ["???", "????", "? ? ?"]]);
        switch _topicL do {
            case "greeting": { _sess set [4, true] };
            case "car": { _sess set [5, true] };
            case "opfor": { _sess set [6, _opforClicks + 1] };
            case "rumours": { _sess set [8, true] };
            case "arrest": { _sess set [9, true] };
        };
        [_reply, _sess, _uid, _player, _netId, false, _langOk] call _finish;
    };

    private _reply = "";
    private _lineIntel = false;

    switch _topicL do {
        case "greeting": {
            _sess set [4, true];
            if (_positive) then {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkGreetingPositive", ["Hello. Can I help you?", "Good day. What do you need?"]]);
            } else {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkGreetingNegative", ["What do you want?", "Leave me alone."]]);
            };
        };
        case "opfor": {
            private _enemySide = missionNamespace getVariable ["FADE_sideEnemy", east];
            private _rad = missionNamespace getVariable ["FADE_civTalkOpforRadiusM", 1000];
            private _near = _civ nearEntities [["Man"], _rad];
            _near = _near select {
                alive _x && {!isPlayer _x} && {side _x == _enemySide} && {_x isKindOf "Man"}
            };
            if (!_positive) then {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkRefuseOpfor", ["I'm not telling you anything.", "I have nothing to say to you."]]);
            } else {
                if (_opforClicks == 0) then {
                    if (_near isEqualTo []) then {
                        _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkOpforNone", ["I have not seen any soldiers.", "No, nothing like that around here."]]);
                    } else {
                        private _ch = missionNamespace getVariable ["FADE_civTalkIntelChance", 0.75];
                        _ch = (_ch max 0) min 1;
                        if (random 1 > _ch) then {
                            _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkOpforUnsure", ["I am not sure.", "Maybe, I did not get a good look."]]);
                        } else {
                            private _u = selectRandom _near;
                            private _dn = getText (configFile >> "CfgVehicles" >> typeOf _u >> "displayName");
                            if (_dn == "") then { _dn = typeOf _u };
                            private _grid = mapGridPosition _u;
                            _reply = format ["Yes, I saw a %1 at grid %2 just now!", _dn, _grid];
                            _lineIntel = true;
                        };
                    };
                } else {
                    if (_near isEqualTo []) then {
                        _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkOpforNone", ["I have not seen any soldiers.", "No, nothing like that around here."]]);
                    } else {
                        private _ch2 = missionNamespace getVariable ["FADE_civTalkOpforFollowupIntelChance", 0.5];
                        _ch2 = (_ch2 max 0) min 1;
                        if (random 1 > _ch2) then {
                            _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkOpforUnsure", ["I am not sure.", "Maybe, I did not get a good look."]]);
                        } else {
                            private _u = selectRandom _near;
                            private _dn = getText (configFile >> "CfgVehicles" >> typeOf _u >> "displayName");
                            if (_dn == "") then { _dn = typeOf _u };
                            private _grid = mapGridPosition _u;
                            _reply = format ["Yes, I saw a %1 at grid %2 just now!", _dn, _grid];
                            _lineIntel = true;
                        };
                    };
                };
            };
            if (_opforClicks == 0) then {
                _sess set [6, 1];
                _sess set [7, _lineIntel];
            } else {
                _sess set [6, 2];
            };
        };
        case "car": {
            _sess set [5, true];
            if (!_positive) then {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkRefuseCar", ["Go away.", "Find your own ride."]]);
            } else {
                private _rad = missionNamespace getVariable ["FADE_civTalkCarRadiusM", 250];
                private _vehs = nearestObjects [getPosATL _civ, ["Car", "Truck", "Motorcycle"], _rad];
                _vehs = _vehs select {
                    alive _x && { crew _x isEqualTo [] } && {
                        side _x == civilian || { _x getVariable ["FADE_ambientParkedVeh", false] }
                    }
                };
                if (_vehs isEqualTo []) then {
                    _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkCarNone", ["I do not know of any free car nearby.", "Sorry, no empty vehicle around here."]]);
                } else {
                    private _v = _vehs select 0;
                    private _best = _v;
                    private _bestD = _civ distance _v;
                    { private _d = _civ distance _x; if (_d < _bestD) then { _bestD = _d; _best = _x } } forEach _vehs;
                    private _vdn = getText (configFile >> "CfgVehicles" >> typeOf _best >> "displayName");
                    if (_vdn == "") then { _vdn = typeOf _best };
                    private _dist = round _bestD;
                    private _bear = [_civ getDir _best] call FADE_civTalk_bearingWord;
                    _reply = format ["Yes, there is a %1 about %2 m away, bearing %3.", _vdn, _dist, _bear];
                    _lineIntel = true;
                };
            };
        };
        case "rumours": {
            _sess set [8, true];
            if (_positive) then {
                private _global = missionNamespace getVariable ["FADE_globalMission", []];
                private _mt = _global param [0, ""];
                private _qrfTypes = missionNamespace getVariable ["FADE_globalMissionTypesWithQrf", []];
                private _qrfRumour = (_mt != "") && { _mt in _qrfTypes } && { random 1 < 0.52 };
                if (_qrfRumour) then {
                    _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkRumoursPositiveQrf", ["Word is, when it gets loud, their trucks come quick."]]);
                } else {
                    _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkRumoursPositive", ["They say the road is quiet."]]);
                };
            } else {
                _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkRumoursNegative", ["I have nothing to tell you."]]);
            };
        };
        case "arrest": {
            _sess set [9, true];
            // Arrest always succeeds (not gated by session _positive / FADE_civTalkPositiveChance).
            _reply = selectRandom (missionNamespace getVariable ["FADE_civTalkArrestComply", ["I am not resisting."]]);
            if !(isNil "ace_captives_fnc_setHandcuffed") then {
                [_civ, true, _player] remoteExecCall ["ace_captives_fnc_setHandcuffed", _civ];
            };
            private _rad = missionNamespace getVariable ["FADE_civTalkArrestUncooperativeRadiusM", 500];
            [_civ, _rad] call FADE_civTalk_markNearbyUncooperative;
        };
        default { _reply = "..."; };
    };

    private _ctxCh = missionNamespace getVariable ["FADE_civTalkContextAppendChance", 0.35];
    if (_reply != "" && {_reply != "..."} && {_topicL in ["greeting", "opfor", "car", "rumours"]} && { random 1 < _ctxCh }) then {
        private _extra = [_civ] call FADE_civTalk_contextLines;
        if (_extra != "") then {
            private _nl = toString [10];
            _reply = _reply + _nl + _extra;
        };
    };

    [_reply, _sess, _uid, _player, _netId, _lineIntel, _langOk] call _finish;
};

// -----------------------------------------------------------------------------
FADE_civTalk_end = {
    if (!isServer) exitWith {};
    params [["_player", objNull]];
    if (isNull _player || {!isPlayer _player}) exitWith {};
    private _uid = getPlayerUID _player;
    private _sess = FADE_civTalk_sessions getOrDefault [_uid, []];
    if (count _sess < 1) exitWith {};
    private _netId = _sess select 0;
    FADE_civTalk_sessions deleteAt _uid;
    private _civ = [_netId] call FADE_civTalk_resolveCiv;
    if (!isNull _civ) then {
        if !(_civ getVariable ["FADE_baseNpcTalk", false]) then {
            [_civ] call FADE_civTalk_clearCivMoveLock;
        };
        if (_civ getVariable ["FADE_civTalkHoldAfterTalk", false]) then {
            _civ setVariable ["FADE_civTalkHoldAfterTalk", false, false];
            private _fn = missionNamespace getVariable ["FADE_civ_restoreAmbientFootPatrol", nil];
            if (!isNil "_fn") then { [_civ] call _fn };
        };
    };
};

publicVariable "FADE_civTalk_start";
publicVariable "FADE_civTalk_topic";
publicVariable "FADE_civTalk_end";
publicVariable "FADE_civTalk_serverCivAnim";
