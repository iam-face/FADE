// =============================================================================
// CivTalkGui.sqf  -  client: talk dialog + cutscene camera + anims (local player only)
// =============================================================================

FAC_civTalkGui_IDD = 60245;

// Diary escape + Intel append: rsc\FADE_ClientCommon.sqf (initPlayerLocal).

if (hasInterface) then {

    FADE_civTalk_replyCtrlSetText = {
        params ["_ctrl", "_raw"];
        if (isNull _ctrl) exitWith {};
        if !(_raw isEqualType "") then { _raw = str _raw };
        // CT_STRUCTURED_TEXT (13): word-wrap; CT_STATIC (0): ST_MULTI in hpp + plain text.
        private _escaped = [_raw] call FADE_client_escapeForDiary;
        if ((ctrlType _ctrl) == 13) then {
            private _size = missionNamespace getVariable ["FADE_civTalkReplyTextSize", 1.1];
            private _align = missionNamespace getVariable ["FADE_civTalkReplyTextAlign", "center"];
            if !(_align in ["left", "center", "right"]) then { _align = "center" };
            // Concat (not format): civ lines may contain "%" which breaks format tokens.
            // Shadow matches title (60246 RscText shadow=2) for readability on sky / bright BG.
            private _st = (
                "<t size='" + str _size + "' color='#ffffff' align='" + _align + "' valign='middle' shadow='2' shadowColor='#000000'>"
                + _escaped + "</t>"
            );
            _ctrl ctrlSetStructuredText parseText _st;
            _ctrl ctrlSetBackgroundColor [0.06, 0.07, 0.10, 0.78];
        } else {
            _ctrl ctrlSetText _raw;
            _ctrl ctrlSetTextColor [1, 1, 1, 1];
            _ctrl ctrlSetTextSelection [0, 0];
        };
        _ctrl ctrlSetFade 0;
        _ctrl ctrlCommit 0;
    };

    // Server remoteExec  -  _unit must be local (player on owner client).
    FADE_civTalk_clientPlayGestureAnimOnUnit = {
        params [["_unit", objNull], ["_anim", ""]];
        if (!hasInterface) exitWith {};
        if (isNull _unit || {!local _unit} || {_anim == ""}) exitWith {};
        _unit switchMove "";
        _unit switchMove _anim;
    };

    FADE_civTalk_clientCloseCivTalkForGesture = {
        if (!hasInterface) exitWith {};
        [] spawn {
            sleep 1.25;
            if (!isNull (findDisplay FAC_civTalkGui_IDD)) then { closeDialog 0 };
        };
    };

    FADE_civTalk_clientMenuSessionUiOrDefault = {
        private _ui = uinamespace getVariable ["FAC_civTalk_sessionUi", []];
        if (count _ui < 5) then {
            private _def = missionNamespace getVariable ["FADE_civTalkBtnOpforDefault", "Seen any OPFOR?"];
            _ui = [true, true, _def, true, true];
        };
        _ui
    };

    // Single vertical column (same IDCs); layout defined inline in CivTalkGui onLoad.
    FADE_civTalk_clientApplyVerticalLayout = {
        if (!hasInterface) exitWith {};
        disableSerialization;
        private _d = findDisplay FAC_civTalkGui_IDD;
        if (isNull _d) exitWith {};
        private _hub = _d displayCtrl 60253;
        if (!isNull _hub) then { _hub ctrlShow false };
        private _reply = _d displayCtrl 60247;
        if (!isNull _reply) then {
            // Taller box so wrapped replies stay readable (structured text, centered).
            _reply ctrlSetPosition [0.22, 0.52, 0.56, 0.14];
            _reply ctrlCommit 0;
        };
        private _bar = _d displayCtrl 60252;
        if (!isNull _bar) then {
            _bar ctrlSetPosition [0.24, 0.668, 0.52, 0.026];
            _bar ctrlCommit 0;
        };
        private _bu = _d displayCtrl 60248;
        private _bl = _d displayCtrl 60249;
        private _br = _d displayCtrl 60250;
        private _bd = _d displayCtrl 60251;
        {
            _x params ["_c", "_y"];
            if (!isNull _c) then {
                _c ctrlSetPosition [0.24, _y, 0.52, 0.044];
                _c ctrlCommit 0;
            };
        } forEach [
            [_bu, 0.702], [_bl, 0.752], [_br, 0.802], [_bd, 0.852]
        ];
        private _title = _d displayCtrl 60246;
        if (!isNull _title) then {
            _title ctrlSetPosition [0.20, 0.908, 0.60, 0.028];
            _title ctrlCommit 0;
        };
    };

    FADE_civTalk_clientMenuApplyLabels = {
        if (!hasInterface) exitWith {};
        disableSerialization;
        private _d = findDisplay FAC_civTalkGui_IDD;
        if (isNull _d) exitWith {};
        private _menu = uinamespace getVariable ["FAC_civTalk_menuPage", "root"];
        private _ui = call FADE_civTalk_clientMenuSessionUiOrDefault;
        _ui params ["_carEn", "_opforEn", "_opforTxt", "_rumoursEn", "_arrestEn"];
        private _bU = _d displayCtrl 60248;
        private _bL = _d displayCtrl 60249;
        private _bR = _d displayCtrl 60250;
        private _bD = _d displayCtrl 60251;
        switch _menu do {
            case "root": {
                if (!isNull _bU) then { _bU ctrlSetText "Talk to..."; _bU ctrlEnable true };
                if (!isNull _bL) then { _bL ctrlSetText "Gesture..."; _bL ctrlEnable true };
                if (!isNull _bR) then { _bR ctrlSetText "Apprehend..."; _bR ctrlEnable true };
                if (!isNull _bD) then { _bD ctrlSetText "Close"; _bD ctrlEnable true };
            };
            case "talk": {
                if (!isNull _bU) then { _bU ctrlSetText _opforTxt; _bU ctrlEnable _opforEn };
                if (!isNull _bL) then { _bL ctrlSetText "Do you have a car I can use?"; _bL ctrlEnable _carEn };
                if (!isNull _bR) then { _bR ctrlSetText "Heard any rumours?"; _bR ctrlEnable _rumoursEn };
                if (!isNull _bD) then { _bD ctrlSetText "Back"; _bD ctrlEnable true };
            };
            case "gesture": {
                if (!isNull _bU) then { _bU ctrlSetText "Go away."; _bU ctrlEnable true };
                if (!isNull _bL) then { _bL ctrlSetText "Stay where you are."; _bL ctrlEnable true };
                if (!isNull _bR) then { _bR ctrlSetText "Get down!"; _bR ctrlEnable true };
                if (!isNull _bD) then { _bD ctrlSetText "Back"; _bD ctrlEnable true };
            };
            case "apprehend": {
                if (!isNull _bU) then { _bU ctrlSetText "Arrest"; _bU ctrlEnable _arrestEn };
                if (!isNull _bL) then { _bL ctrlSetText ""; _bL ctrlEnable false };
                if (!isNull _bR) then { _bR ctrlSetText ""; _bR ctrlEnable false };
                if (!isNull _bD) then { _bD ctrlSetText "Back"; _bD ctrlEnable true };
            };
            case "baseNpc": {
                private _hello = missionNamespace getVariable ["FADE_baseNpcTalkBtnHello", "Hello"];
                private _mission = missionNamespace getVariable ["FADE_baseNpcTalkBtnMission", "Will you come on the mission with us?"];
                private _bye = missionNamespace getVariable ["FADE_baseNpcTalkBtnGoodbye", "Goodbye"];
                if (!isNull _bU) then { _bU ctrlSetText _hello; _bU ctrlEnable true };
                if (!isNull _bL) then { _bL ctrlSetText _mission; _bL ctrlEnable true };
                if (!isNull _bR) then { _bR ctrlSetText ""; _bR ctrlEnable false };
                if (!isNull _bD) then { _bD ctrlSetText _bye; _bD ctrlEnable true };
            };
            default {
                uinamespace setVariable ["FAC_civTalk_menuPage", "root"];
                [] call FADE_civTalk_clientMenuApplyLabels;
            };
        };
    };

    FADE_civTalk_clientPlayerAnim = {
        params [["_phase", "idle"]];
        if (!hasInterface || isNull player) exitWith {};
        player switchMove "";
        private _idle = missionNamespace getVariable ["FADE_civTalkAnimPlayerIdle", "acts_millerIdle"];
        player switchMove _idle;
    };

    // Drop scripted dialog poses immediately (Close, ESC, Unload, teardown).
    FADE_civTalk_clientClearPlayerAnim = {
        if (!hasInterface || isNull player) exitWith {};
        player switchMove "";
    };

    FADE_civTalk_clientDestroyCamera = {
        private _cam = uinamespace getVariable ["FAC_civTalk_cam", objNull];
        if (!isNull _cam) then {
            _cam cameraEffect ["terminate", "BACK"];
            camDestroy _cam;
        };
        uinamespace setVariable ["FAC_civTalk_cam", nil];
    };

    // OTS in Man model space (world ASL): X=right, Y=forward, Z=up from pelvis  -  tracks idle pose; avoids getPosASL/vectorUp drift → sky cam.
    FADE_civTalk_clientApplyCamera = {
        params [["_civ", objNull]];
        if (isNull _civ || isNull player) exitWith {};
        private _backM = missionNamespace getVariable ["FADE_civTalkCamBehindM", 3];
        private _rightM = missionNamespace getVariable ["FADE_civTalkCamRightM", 2];
        private _upM = missionNamespace getVariable ["FADE_civTalkCamHeightAbovePlayerASL", 1];
        private _camASL = player modelToWorld [_rightM, -_backM, _upM];

        private _fov = missionNamespace getVariable ["FADE_civTalkCamFov", 0.2];

        private _cam = "camera" camCreate _camASL;
        uinamespace setVariable ["FAC_civTalk_cam", _cam];
        // Target + commit must run after cameraEffect; object target tracks reliably (eyePos before effect often ignored).
        _cam camSetFov _fov;
        _cam cameraEffect ["internal", "BACK"];
        _cam camSetTarget _civ;
        _cam camCommit 0;
    };

    // Debug: terminate preview camera only (spawned debug civ stays).
    FADE_civTalk_debugStopCamera = {
        if (!hasInterface) exitWith {};
        private _cam = uinamespace getVariable ["FAC_dbg_civTalkCam", objNull];
        if (!isNull _cam) then {
            _cam cameraEffect ["terminate", "BACK"];
            camDestroy _cam;
        };
        uinamespace setVariable ["FAC_dbg_civTalkCam", nil];
    };

    // Debug: camera + delete civ from FADE_civTalk_debugSpawnSceneAndCamera.
    FADE_civTalk_debugResetScene = {
        if (!hasInterface) exitWith {};
        [] call FADE_civTalk_debugStopCamera;
        private _u = uinamespace getVariable ["FAC_dbg_civTalkUnit", objNull];
        if (!isNull _u) then {
            private _g = group _u;
            deleteVehicle _u;
            if (!isNull _g && { count units _g == 0 }) then { deleteGroup _g };
        };
        uinamespace setVariable ["FAC_dbg_civTalkUnit", nil];
    };

    FADE_civTalk_debugApplyPreviewCamera = {
        if (!hasInterface) exitWith {};
        params ["_civ", "_right", "_back", "_up", "_fov", "_useIdleAnim"];
        if (_useIdleAnim && {!isNull player}) then { ["idle"] call FADE_civTalk_clientPlayerAnim };
        private _camASL = player modelToWorld [_right, -_back, _up];
        private _cam = "camera" camCreate _camASL;
        uinamespace setVariable ["FAC_dbg_civTalkCam", _cam];
        _cam camSetFov _fov;
        _cam cameraEffect ["internal", "BACK"];
        _cam camSetTarget _civ;
        _cam camCommit 0;
        systemChat format [
            "FAC civTalk cam: modelToWorld [right %1, -back %2, up %3] FOV %4 | ASL %5",
            _right, _back, _up, _fov, _camASL
        ];
        private _nl = toString [10];
        copyToClipboard (
            format ["FADE_civTalkCamRightM = %1;", _right] + _nl +
            format ["FADE_civTalkCamBehindM = %1;", _back] + _nl +
            format ["FADE_civTalkCamHeightAbovePlayerASL = %1;", _up] + _nl +
            format ["FADE_civTalkCamFov = %1;", _fov] + _nl +
            "// paste into rsc\Config.sqf"
        );
    };

    /*
        Params: [civ, right, back, up, fov, useIdleAnim]
        Use -1 for right/back/up/fov to read missionNamespace defaults.
        civ: objNull → cursorTarget
    */
    FADE_civTalk_debugPreviewCamera = {
        if (!hasInterface) exitWith {};
        params [
            ["_civ", objNull],
            ["_right", -1],
            ["_back", -1],
            ["_up", -1],
            ["_fov", -1],
            ["_useIdleAnim", true]
        ];
        if (isNull _civ) then { _civ = cursorTarget };
        if (isNull _civ || {!alive _civ}) exitWith {
            systemChat "FADE_civTalk debug: aim at a unit (cursorTarget) or pass [civ, ...]";
        };
        if (_right < 0) then { _right = missionNamespace getVariable ["FADE_civTalkCamRightM", 2] };
        if (_back < 0) then { _back = missionNamespace getVariable ["FADE_civTalkCamBehindM", 3] };
        if (_up < 0) then { _up = missionNamespace getVariable ["FADE_civTalkCamHeightAbovePlayerASL", 1] };
        if (_fov < 0) then { _fov = missionNamespace getVariable ["FADE_civTalkCamFov", 0.2] };

        [] call FADE_civTalk_debugStopCamera;
        [_civ, _right, _back, _up, _fov, _useIdleAnim] call FADE_civTalk_debugApplyPreviewCamera;
    };

    /*
        Full setup (Local): same face distance as FADE_civTalk_computeFaceToFace (FADE_civTalkFaceSeparationM),
        civ in front of you facing you, then preview camera. Tweak with FADE_civTalk_debugPreviewCamera on cursorTarget after.
        Params: [sep, right, back, up, fov, useIdleAnim, civClass]  -  use -1 for sep/right/back/up/fov for Config defaults; civClass "" = C_man_1.
    */
    FADE_civTalk_debugSpawnSceneAndCamera = {
        if (!hasInterface || isNull player) exitWith {};
        params [
            ["_sep", -1],
            ["_right", -1],
            ["_back", -1],
            ["_up", -1],
            ["_fov", -1],
            ["_useIdleAnim", true],
            ["_civClass", ""]
        ];
        if (_sep < 0) then { _sep = missionNamespace getVariable ["FADE_civTalkFaceSeparationM", 3] };
        if (_right < 0) then { _right = missionNamespace getVariable ["FADE_civTalkCamRightM", 2] };
        if (_back < 0) then { _back = missionNamespace getVariable ["FADE_civTalkCamBehindM", 3] };
        if (_up < 0) then { _up = missionNamespace getVariable ["FADE_civTalkCamHeightAbovePlayerASL", 1] };
        if (_fov < 0) then { _fov = missionNamespace getVariable ["FADE_civTalkCamFov", 0.2] };
        if (_civClass == "") then { _civClass = "C_man_1" };

        [] call FADE_civTalk_debugResetScene;

        private _pATL = getPosATL player;
        private _pDir = getDir player;
        private _civATL = +_pATL;
        private _cXY = _pATL getPos [_sep, _pDir];
        _civATL set [0, _cXY select 0];
        _civATL set [1, _cXY select 1];
        _civATL set [2, _pATL select 2];

        private _civ = createAgent [_civClass, _civATL, [], 0, "NONE"];
        _civ setPosATL _civATL;
        private _dirCiv = [_civATL, _pATL] call BIS_fnc_dirTo;
        _civ setDir _dirCiv;
        player setDir ([_pATL, _civATL] call BIS_fnc_dirTo);
        _civ disableAI "MOVE";
        doStop _civ;

        uinamespace setVariable ["FAC_dbg_civTalkUnit", _civ];

        systemChat format [
            "FAC civTalk debug scene: sep %1 m (FADE_civTalkFaceSeparationM). Tweak: [cursorTarget, r,b,u,f,false] call FADE_civTalk_debugPreviewCamera",
            _sep
        ];

        [_civ, _right, _back, _up, _fov, _useIdleAnim] call FADE_civTalk_debugApplyPreviewCamera;
    };

    // Server sends stance after snapping civ; local only: fade → move → camera → fade in → dialog.
    FADE_civTalk_clientBeginCutscene = {
        params ["_pATL", "_pDir", "_positive", "_netId", ["_langOk", true], ["_sessionKind", "ambient"]];
        if (!hasInterface) exitWith {};
        uinamespace setVariable ["FAC_civTalk_netId", _netId];
        uinamespace setVariable ["FAC_civTalk_positive", _positive];
        uinamespace setVariable ["FAC_civTalk_langOk", _langOk];
        uinamespace setVariable ["FAC_civTalk_sessionKind", _sessionKind];
        uinamespace setVariable ["FAC_civTalk_replyId", 0];
        uinamespace setVariable ["FAC_civTalk_teardownDone", false];
        if (!isNull (findDisplay FAC_civTalkGui_IDD)) exitWith {};
        [_pATL, _pDir, _netId] spawn {
            params ["_pATL", "_pDir", "_netId"];
            private _fo = missionNamespace getVariable ["FADE_civTalkFadeOutSec", 1.2];
            private _fi = missionNamespace getVariable ["FADE_civTalkFadeInSec", 1];
            cutText ["", "BLACK OUT", _fo max 0.1];
            sleep (_fo max 0.1);
            if (!isNull player) then {
                player setPosATL _pATL;
                player setDir _pDir;
            };
            [] call FADE_civTalk_clientDestroyCamera;
            private _civ = _netId call BIS_fnc_objectFromNetId;
            if (!isNull player && {!isNull _civ}) then {
                ["idle"] call FADE_civTalk_clientPlayerAnim;
                sleep 0.05;
                [_civ] call FADE_civTalk_clientApplyCamera;
            };
            cutText ["", "BLACK IN", _fi max 0.1];
            sleep (_fi max 0.1);
            if !(createDialog "RscDisplayCivTalk") then {
                [] call FADE_civTalk_clientDestroyCamera;
                [] call FADE_civTalk_clientClearPlayerAnim;
                systemChat "CIV TALK: dialog missing.";
                if (!isNull player) then { player remoteExec ["FADE_civTalk_end", 2] };
            };
        };
    };

    FADE_civTalk_clientSetReply = {
        params [["_text", ""], ["_ui", []], ["_autoClose", false]];
        if (!hasInterface) exitWith {};
        disableSerialization;
        private _d = findDisplay FAC_civTalkGui_IDD;
        if (isNull _d) exitWith {};
        private _c = _d displayCtrl 60247;
        if (!isNull _c) then {
            [_c, _text] call FADE_civTalk_replyCtrlSetText;
        };
        if (count _ui >= 5) then {
            uinamespace setVariable ["FAC_civTalk_sessionUi", _ui];
            [] call FADE_civTalk_clientMenuApplyLabels;
        };
        if (_autoClose) then {
            private _delay = missionNamespace getVariable ["FADE_baseNpcTalkGoodbyeCloseDelay", 2.5];
            [_delay max 0.5] spawn {
                params ["_delay"];
                sleep _delay;
                if (!isNull (findDisplay FAC_civTalkGui_IDD)) then { closeDialog 0 };
            };
        };
    };

    FADE_civTalk_clientTeardown = {
        if (!hasInterface) exitWith {};
        if (uinamespace getVariable ["FAC_civTalk_teardownDone", false]) exitWith {};
        uinamespace setVariable ["FAC_civTalk_teardownDone", true];
        private _fo = missionNamespace getVariable ["FADE_civTalkFadeOutSec", 1.2];
        private _fi = missionNamespace getVariable ["FADE_civTalkFadeInSec", 1];
        uinamespace setVariable ["FAC_civTalk_replyId", 1e9];
        [] call FADE_civTalk_clientClearPlayerAnim;
        cutText ["", "BLACK OUT", _fo max 0.1];
        sleep (_fo max 0.1);
        [] call FADE_civTalk_clientDestroyCamera;
        if (!isNull player) then {
            [] call FADE_civTalk_clientClearPlayerAnim;
            player remoteExec ["FADE_civTalk_end", 2];
        };
        cutText ["", "BLACK IN", _fi max 0.1];
        sleep (_fi max 0.1);
    };

    // Legacy name kept if referenced elsewhere  -  delegates to cutscene entry.
    FADE_civTalk_clientOpen = {
        params ["_positive", "_netId"];
        private _p = getPosATL player;
        private _langOk = !(missionNamespace getVariable ["FADE_civTalkInterpretersOnly", false])
            || { player getVariable ["FADE_civInterpreter", false] };
        [_p, getDir player, _positive, _netId, _langOk] call FADE_civTalk_clientBeginCutscene;
    };

    FADE_civTalk_addLocalAction = {
        params [["_unit", objNull]];
        if (!hasInterface) exitWith {};
        if (isNull _unit || {!alive _unit}) exitWith {};
        private _baseNetId = missionNamespace getVariable ["FADE_baseNpcTalk_netId", ""];
        private _isBaseNpc = _unit getVariable ["FADE_baseNpcTalk", false]
            || { _baseNetId != "" && { netId _unit == _baseNetId } };
        private _isAmbientCiv = _unit getVariable ["FADE_ambientCiv", false];
        if (!_isBaseNpc && {!_isAmbientCiv}) exitWith {};
        if (_unit getVariable ["FADE_civTalk_actAdded_local", false]) exitWith {};
        private _maxD = missionNamespace getVariable ["FADE_civTalkMaxDistM", 6];
        private _actionText = if (_isBaseNpc) then {
            missionNamespace getVariable ["FADE_baseNpcTalkActionText", "Talk to S Wordsman"]
        } else {
            "Talk to civilian"
        };
        private _cond = if (_isBaseNpc) then {
            format ["alive _target && {_target distance player < %1}", (_maxD + 1)]
        } else {
            format [
                "alive _target && {_target distance player < %1} && {missionNamespace getVariable ['FADE_civiliansEnabled', true]}",
                (_maxD + 1)
            ]
        };
        private _actionId = _unit addAction [
            _actionText,
            {
                _this params ["_target", "_caller"];
                [_caller, netId _target] remoteExec ["FADE_civTalk_start", 2];
            },
            nil,
            6,
            true,
            true,
            "",
            _cond,
            (_maxD + 1)
        ];
        if (_actionId isEqualType 0 && { _actionId >= 0 }) then {
            _unit setVariable ["FADE_civTalk_actAdded_local", true];
            _unit setVariable ["FADE_civTalk_actionId_local", _actionId];
        };
    };

    FADE_civTalk_refreshBaseNpcAction = {
        if (!hasInterface) exitWith {};
        private _fn = missionNamespace getVariable ["FADE_civTalk_addLocalAction", {}];
        if !(_fn isEqualType {}) exitWith {};
        private _nid = missionNamespace getVariable ["FADE_baseNpcTalk_netId", ""];
        if (_nid isEqualTo "") exitWith {};
        private _u = _nid call BIS_fnc_objectFromNetId;
        if (isNull _u) then {
            { if (netId _x == _nid) exitWith { _u = _x } } forEach allUnits;
        };
        if (!isNull _u && { alive _u }) then {
            private _idFn = missionNamespace getVariable ["FADE_baseNpc_clientSetIdentity", {}];
            if (_idFn isEqualType {}) then {
                [_u, "FAC_baseNPC_wordsman"] call _idFn;
            };
            if (!(_u getVariable ["FADE_civTalk_actAdded_local", false])) then {
                [_u] call _fn;
            };
        };
    };

    if (isNil "FAC_baseNpcTalk_netId_pvh") then {
        FAC_baseNpcTalk_netId_pvh = "FADE_baseNpcTalk_netId" addPublicVariableEventHandler {
            params ["", "_val"];
            if (_val isEqualType "" && { _val != "" }) then {
                [] call FADE_civTalk_refreshBaseNpcAction;
            };
        };
    };

    missionNamespace setVariable ["FADE_civTalk_addLocalAction", FADE_civTalk_addLocalAction];
    missionNamespace setVariable ["FADE_civTalk_refreshBaseNpcAction", FADE_civTalk_refreshBaseNpcAction];
};

FAC_civTalkGui_fnc = {
    params ["_action", ["_params", []]];

    switch _action do {
        case "onLoad": {
            private _display = findDisplay FAC_civTalkGui_IDD;
            if (isNull _display) exitWith {};
            missionNamespace setVariable ["FAC_civTalkGui_fnc", FAC_civTalkGui_fnc];
            uinamespace setVariable ["FAC_civTalkGui_fnc", FAC_civTalkGui_fnc];
            _display displayAddEventHandler ["Unload", { 0 spawn { [] call FADE_civTalk_clientTeardown } }];
            private _sessionKind = uinamespace getVariable ["FAC_civTalk_sessionKind", "ambient"];
            if (_sessionKind isEqualTo "baseNpc") then {
                uinamespace setVariable ["FAC_civTalk_menuPage", "baseNpc"];
                uinamespace setVariable ["FAC_civTalk_sessionUi", [true, false, "", false, false]];
            } else {
                uinamespace setVariable ["FAC_civTalk_menuPage", "root"];
                private _defOp = missionNamespace getVariable ["FADE_civTalkBtnOpforDefault", "Seen any OPFOR?"];
                uinamespace setVariable ["FAC_civTalk_sessionUi", [true, true, _defOp, true, true]];
            };
            [] call FADE_civTalk_clientApplyVerticalLayout;
            private _reply = _display displayCtrl 60247;
            if (!isNull _reply) then {
                _reply ctrlSetTextColor [1, 1, 1, 1];
                _reply ctrlCommit 0;
                private _prompt = if (_sessionKind isEqualTo "baseNpc") then {
                    "What do you want?"
                } else {
                    "Choose an option below."
                };
                [_reply, _prompt] call FADE_civTalk_replyCtrlSetText;
            };
            private _title = _display displayCtrl 60246;
            if (!isNull _title) then {
                _title ctrlSetTextColor [1, 1, 1, 1];
                _title ctrlSetFade 0;
                _title ctrlCommit 0;
                private _nid = uinamespace getVariable ["FAC_civTalk_netId", ""];
                private _civ = if (_nid != "") then { _nid call BIS_fnc_objectFromNetId } else { objNull };
                if (isNull _civ) then {
                    _title ctrlSetText "Talking to civilian";
                } else {
                    private _dn = name _civ;
                    if (_dn == "") then { _dn = "Civilian" };
                    _title ctrlSetText format ["Talking to %1", _dn];
                };
            };
            private _bar = _display displayCtrl 60252;
            if (!isNull _bar) then {
                if (uinamespace getVariable ["FAC_civTalk_langOk", true]) then {
                    _bar ctrlShow false;
                } else {
                    _bar ctrlShow true;
                    _bar ctrlSetText (missionNamespace getVariable [
                        "FADE_civTalkLangBarrierText",
                        "You do not understand the language this person is speaking."
                    ]);
                };
            };
            [] call FADE_civTalk_clientMenuApplyLabels;
        };

        case "radial": {
            if (isNull (findDisplay FAC_civTalkGui_IDD)) exitWith {};
            _params params [["_dir", ""]];
            if (_dir == "" || isNull player) exitWith {};
            private _nid = uinamespace getVariable ["FAC_civTalk_netId", ""];
            if (_nid == "") exitWith {};
            private _menu = uinamespace getVariable ["FAC_civTalk_menuPage", "root"];
            private _ui = call FADE_civTalk_clientMenuSessionUiOrDefault;
            _ui params ["_carEn", "_opforEn", "_opforTxt", "_rumoursEn", "_arrestEn"];
            private _dirL = toLower _dir;
            if (_menu isEqualTo "baseNpc") then {
                switch _dirL do {
                    case "up": { [player, "base_npc_hello"] remoteExec ["FADE_civTalk_topic", 2] };
                    case "left": { [player, "base_npc_mission"] remoteExec ["FADE_civTalk_topic", 2] };
                    case "down": { [player, "base_npc_goodbye"] remoteExec ["FADE_civTalk_topic", 2] };
                };
            } else {
            if (_dirL == "down") then {
                switch _menu do {
                    case "root": { closeDialog 0 };
                    case "talk";
                    case "gesture";
                    case "apprehend": {
                        uinamespace setVariable ["FAC_civTalk_menuPage", "root"];
                        [] call FADE_civTalk_clientMenuApplyLabels;
                    };
                };
            } else {
                switch _menu do {
                    case "root": {
                        switch _dirL do {
                            case "up": {
                                uinamespace setVariable ["FAC_civTalk_menuPage", "talk"];
                                [] call FADE_civTalk_clientMenuApplyLabels;
                            };
                            case "left": {
                                uinamespace setVariable ["FAC_civTalk_menuPage", "gesture"];
                                [] call FADE_civTalk_clientMenuApplyLabels;
                            };
                            case "right": {
                                uinamespace setVariable ["FAC_civTalk_menuPage", "apprehend"];
                                [] call FADE_civTalk_clientMenuApplyLabels;
                            };
                        };
                    };
                    case "talk": {
                        switch _dirL do {
                            case "up": { if (_opforEn) then { [player, "opfor"] remoteExec ["FADE_civTalk_topic", 2] } };
                            case "left": { if (_carEn) then { [player, "car"] remoteExec ["FADE_civTalk_topic", 2] } };
                            case "right": { if (_rumoursEn) then { [player, "rumours"] remoteExec ["FADE_civTalk_topic", 2] } };
                        };
                    };
                    case "gesture": {
                        switch _dirL do {
                            case "up": { [player, "gesture_away"] remoteExec ["FADE_civTalk_topic", 2] };
                            case "left": { [player, "gesture_stay"] remoteExec ["FADE_civTalk_topic", 2] };
                            case "right": { [player, "gesture_down"] remoteExec ["FADE_civTalk_topic", 2] };
                        };
                    };
                    case "apprehend": {
                        if (_dirL == "up" && {_arrestEn}) then {
                            [player, "arrest"] remoteExec ["FADE_civTalk_topic", 2];
                        };
                    };
                };
            };
            };
        };

        case "topic": {
            if (isNull (findDisplay FAC_civTalkGui_IDD)) exitWith {};
            _params params [["_topic", ""]];
            if (_topic == "") exitWith {};
            if (isNull player) exitWith {};
            private _nid = uinamespace getVariable ["FAC_civTalk_netId", ""];
            if (_nid == "") exitWith {};
            [player, _topic] remoteExec ["FADE_civTalk_topic", 2];
        };
    };
};

missionNamespace setVariable ["FAC_civTalkGui_fnc", FAC_civTalkGui_fnc];
