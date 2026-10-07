// =============================================================================
// FADE_MOTDBoard.sqf  -  dynamic Message of the Day on Eden MOTD boards (server)
// =============================================================================

FADE_motdBoard_intervalSec = 300; // 5 minutes
FADE_motdBoard_wrapChars = 28;    // ~line length on 512x512 Caveat @ 0.07 (see Eden default)
FADE_motdBoard_boardNames = ["board_MOTD", "board_MOTD_1"];

FADE_motdBoard_messages = [
    "We recommend not feeding the Gunn^3r any dairy products.",
    "Remember: Don't stand there, <name>",
    "Do not look directly at <name>",
    "Has anyone seen <name>?",
    "Happy birthday <name>!",
    "Todays welcome to country conductor: <name>",
    "<name> please report to Rhodesy's office",
    "Do not take SDE's STANAGs",
    "Have you seen Wazza Driscoll?",
    "Avoid overenthusiasm",
    "Remember the tactical onion",
    "El Cheeto is still at large",
    "Welcome to the rice fields",
    "Have you seen Alien?",
    "The LAW is away",
    "It is a direct hit on the T80s behalf",
    "This is just an overwhelming experience for me right now",
    "An unbelievable feeling, as that gust of air just rushes past your face, and you're pushed into the ground, into your shoes",
    "I just can't believe what I am witnessing right now",
    "Pretty soon the tanks will roll out and meet them in a gruesome battle for defiance"
];

FADE_motdBoard_replaceToken = {
    params ["_text", "_token", "_replacement"];
    if (_token == "") exitWith { _text };
    private _tokenLen = count _token;
    private _out = "";
    private _pos = 0;
    while { _pos < count _text } do {
        private _idx = _text find [_token, _pos];
        if (_idx < 0) exitWith {
            _out = _out + (_text select [_pos, count _text - _pos]);
        };
        _out = _out + (_text select [_pos, _idx - _pos]) + _replacement;
        _pos = _idx + _tokenLen;
    };
    _out
};

FADE_motdBoard_resolveMessage = {
    params [["_msg", ""]];
    if (_msg find "<name>" < 0) exitWith { _msg };
    private _players = allPlayers select { alive _x };
    private _name = "someone";
    if (count _players > 0) then {
        _name = name (selectRandom _players);
    };
    [_msg, "<name>", [_name] call FADE_textureText_sanitize] call FADE_motdBoard_replaceToken
};

FADE_motdBoard_pickTemplate = {
    params [["_exclude", []]];
    private _pool = FADE_motdBoard_messages select { !(_x in _exclude) };
    if (count _pool == 0) then { _pool = FADE_motdBoard_messages };
    selectRandom _pool
};

FADE_motdBoard_pickMessage = {
    params [["_exclude", []]];
    [[_exclude] call FADE_motdBoard_pickTemplate] call FADE_motdBoard_resolveMessage
};

FADE_motdBoard_buildTexture = {
    params [["_message", ""]];
    private _body = [[_message] call FADE_textureText_sanitize, FADE_motdBoard_wrapChars] call FADE_textureText_wrap;
    format [
        "#(rgb,512,512,1)text(1,1,""Caveat"",0.07,""#FFFFFF"",""#000000"",""%1"")",
        _body
    ]
};

FADE_motdBoard_resolveBoard = {
    params [["_boardName", "board_MOTD"]];
    private _board = missionNamespace getVariable [_boardName, objNull];
    if (!isNull _board) exitWith { _board };
    private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
    private _i = _scan findIf { vehicleVarName _x == _boardName };
    if (_i >= 0) then { _scan select _i } else { objNull }
};

FADE_motdBoard_update = {
    if (!isServer) exitWith {};
    private _usedTemplates = [];
    {
        private _board = [_x] call FADE_motdBoard_resolveBoard;
        if (isNull _board) then { continue };
        private _template = [_usedTemplates] call FADE_motdBoard_pickTemplate;
        _usedTemplates pushBack _template;
        private _texture = [[_template] call FADE_motdBoard_resolveMessage] call FADE_motdBoard_buildTexture;
        _board setObjectTextureGlobal [0, _texture];
    } forEach FADE_motdBoard_boardNames;
};

FADE_motdBoard_start = {
    if (!isServer) exitWith {};
    [] spawn {
        sleep 0.5;
        while { true } do {
            [] call FADE_motdBoard_update;
            sleep FADE_motdBoard_intervalSec;
        };
    };
};

missionNamespace setVariable ["FADE_motdBoard_update", FADE_motdBoard_update];
