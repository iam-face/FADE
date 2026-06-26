// =============================================================================
// FADE_MOTDBoard.sqf  -  dynamic Message of the Day on Eden board_MOTD (server)
// =============================================================================

FADE_motdBoard_intervalSec = 600; // 10 minutes
FADE_motdBoard_wrapChars = 28;    // ~line length on 512x512 Caveat @ 0.07 (see Eden default)

FADE_motdBoard_messages = [
    "We recommend not feeding the Gunn^3r any dairy products.",
    "Remember: Don't stand there",
    "Do not look directly at <name>",
    "Do not take SDE's STANAGs",
    "Have you seen Wazza Driscoll?",
    "Avoid overenthusiasm",
    "El Cheeto is still at large",
    "Welcome to the rice fields",
    "Have you seen Alien?",
    "This is just an overwhelming experience for me right now",
    "An unbelievable feeling, as that gust of air just rushes past your face, and you're pushed into the ground, into your shoes",
    "I just can't believe what I am witnessing right now",
    "Pretty soon the tanks will roll out and meet them in a gruesome battle for defiance"
];

FADE_motdBoard_sanitizeTextureText = {
    params [["_text", ""]];
    if (!(_text isEqualType "")) then { _text = str _text };
    private _out = [];
    {
        if (_x == 34) then { _out append (toArray "'") } else { _out pushBack _x };
    } forEach (toArray _text);
    toString _out
};

FADE_motdBoard_wrapText = {
    params [["_text", ""], ["_maxChars", FADE_motdBoard_wrapChars]];
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
    _lines joinString (toString [92, 110]) // literal \n for procedural texture
};

FADE_motdBoard_resolveMessage = {
    params [["_msg", ""]];
    if (_msg find "<name>" < 0) exitWith { _msg };
    private _players = allPlayers select { alive _x };
    private _name = "someone";
    if (count _players > 0) then {
        _name = name (selectRandom _players);
    };
    (_msg splitString "<name>") joinString _name
};

FADE_motdBoard_pickMessage = {
    [selectRandom FADE_motdBoard_messages] call FADE_motdBoard_resolveMessage
};

FADE_motdBoard_buildTexture = {
    params [["_message", ""]];
    private _body = [[_message] call FADE_motdBoard_sanitizeTextureText] call FADE_motdBoard_wrapText;
    format [
        "#(rgb,512,512,1)text(1,1,""Caveat"",0.07,""#FFFFFF"",""#000000"",""%1"")",
        _body
    ]
};

FADE_motdBoard_resolveBoard = {
    private _board = missionNamespace getVariable ["board_MOTD", objNull];
    if (!isNull _board) exitWith { _board };
    private _scan = allMissionObjects "Land_MapBoard_01_Wall_F";
    private _i = _scan findIf { vehicleVarName _x == "board_MOTD" };
    if (_i >= 0) then { _scan select _i } else { objNull }
};

FADE_motdBoard_update = {
    if (!isServer) exitWith {};
    private _board = [] call FADE_motdBoard_resolveBoard;
    if (isNull _board) exitWith {};
    private _texture = [[] call FADE_motdBoard_pickMessage] call FADE_motdBoard_buildTexture;
    _board setObjectTextureGlobal [0, _texture];
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
