// BuildCommon.sqf - catalog lookup, base-radius check, sign text, client object actions.
// Compiled on server and client. Place / remove / sign authority stays in ServerGameplayBuild.sqf.

if (isNil "FADE_buildCatalog") then {
    call compile preprocessFileLineNumbers "rsc\BuildCatalog.sqf";
};

FADE_build_findEntry = {
    params [["_class", ""]];
    if (_class == "") exitWith { [] };
    private _index = missionNamespace getVariable ["FADE_buildCatalogIndex", nil];
    if (!isNil "_index" && { _index isEqualType createHashMap }) exitWith {
        _index getOrDefault [_class, []]
    };
    private _hit = [];
    {
        if ((_x select 0) == _class) exitWith { _hit = _x };
    } forEach (missionNamespace getVariable ["FADE_buildCatalog", []]);
    _hit
};

// Player text for a wall sign. Real newlines become the \n token. Quotes become apostrophes.
FADE_build_signClean = {
    params [["_text", ""]];
    if !(_text isEqualType "") exitWith { "" };
    private _chars = [];
    {
        switch (_x) do {
            case 10: { _chars append [92, 110] };
            case 13: {};
            case 34: { _chars pushBack 39 };
            default { _chars pushBack _x };
        };
    } forEach (toArray _text);
    private _clean = toString _chars;
    if (count _clean > 180) then { _clean = _clean select [0, 180] };
    _clean
};

// format inserts the text as-is. The same pattern is used for the mission-slot boards.
// Empty text returns "". The server sends "#reset" for that case.
FADE_build_signTexture = {
    params [["_text", ""]];
    private _clean = [_text] call FADE_build_signClean;
    if (_clean == "") exitWith { "" };
    format [
        "#(rgb,512,512,1)text(0,1,""Caveat"",0.1,""#000000"",""#FFFFFF"",""%1"")",
        _clean
    ]
};

// Highest texture slot, or -1 when the object has none.
// Slot 0 stays the material when a higher slot exists. Text goes in the last slot.
// Empty getObjectTextures means the object cannot take one. Config covers a list that is not ready yet.
FADE_build_writeSlot = {
    params [["_obj", objNull], ["_class", ""]];
    if (_class == "" && { !isNull _obj }) then { _class = typeOf _obj };
    private _n = 0;
    if (!isNull _obj) then { _n = count (getObjectTextures _obj) };
    if (_n == 0 && { _class != "" }) then {
        _n = count getArray (configFile >> "CfgVehicles" >> _class >> "hiddenSelections");
    };
    if (_n == 0 && { _class != "" }) then {
        _n = count getArray (configFile >> "CfgVehicles" >> _class >> "hiddenSelectionsTextures");
    };
    if (_n < 1) exitWith { -1 };
    _n - 1
};

FADE_build_logisticsOn = {
    (missionNamespace getVariable ["FAC_param_buildLogistics", 0]) > 0
};

// 0 = within FADE_buildRadius of base. 1 = no radius limit. Water is still rejected.
FADE_build_anywhere = {
    (missionNamespace getVariable ["FAC_param_buildArea", 0]) > 0
};

// "" when the spot is free. Else "water" or "radius".
// Object overlap is not checked. Base props made the footprint test block almost every spot.
FADE_build_spotBlocked = {
    params ["_class", "_pos", "_dir", ["_ignore", objNull]];
    if !(_pos isEqualType []) exitWith { "radius" };
    if (count _pos < 2) exitWith { "radius" };
    if (surfaceIsWater [_pos select 0, _pos select 1]) exitWith { "water" };
    private _base = missionNamespace getVariable ["FADE_basePos", []];
    private _radius = missionNamespace getVariable ["FADE_buildRadius", 1000];
    if (count _base < 2) exitWith { "radius" };
    if (!([] call FADE_build_anywhere) && { (_pos distance2D _base) > _radius }) exitWith { "radius" };
    ""
};

// ACE object Interact (type 0), not self-interact. Local to each client; the server remoteExecs this.
FAC_build_clientAddRemove = {
    params [["_obj", objNull]];
    if (!hasInterface) exitWith {};
    if (isNull _obj) exitWith {};
    if (_obj getVariable ["FAC_build_removeAdded", false]) exitWith {};
    if (isNil "ace_interact_menu_fnc_createAction" || { isNil "ace_interact_menu_fnc_addActionToObject" }) exitWith {};
    private _act = [
        "FAC_build_destroy",
        "Destroy",
        "",
        {
            params ["_target", "_caller"];
            if (isNull _target || { isNull _caller }) exitWith {};
            [_caller, netId _target] remoteExec ["FADE_build_remove", 2];
        },
        {
            params ["_target", "_caller"];
            alive _target && { _target getVariable ["FADE_build_placed", false] } && {
                isNil "FAC_lobbyParams_callAccess" || { ["FAC_playerCanBuild"] call FAC_lobbyParams_callAccess }
            }
        }
    ] call ace_interact_menu_fnc_createAction;
    [_obj, 0, ["ACE_MainActions"], _act] call ace_interact_menu_fnc_addActionToObject;
    if (([_obj] call FADE_build_writeSlot) >= 0) then {
        private _write = [
            "FAC_build_signWrite",
            "Write",
            "",
            {
                params ["_target", "_caller"];
                if (isNull _target || { isNull _caller }) exitWith {};
                missionNamespace setVariable ["FAC_build_signNetId", netId _target];
                if (isNil "FAC_buildSignGui_fnc") then {
                    call compile preprocessFileLineNumbers "rsc\BuildSignGui.sqf";
                };
                ["open", []] call FAC_buildSignGui_fnc;
            },
            {
                params ["_target", "_caller"];
                alive _target && { _target getVariable ["FADE_build_placed", false] } && {
                    isNil "FAC_lobbyParams_callAccess" || { ["FAC_playerCanBuild"] call FAC_lobbyParams_callAccess }
                }
            }
        ] call ace_interact_menu_fnc_createAction;
        [_obj, 0, ["ACE_MainActions"], _write] call ace_interact_menu_fnc_addActionToObject;
    };
    _obj setVariable ["FAC_build_removeAdded", true];
};

FAC_build_clientScan = {
    if (!hasInterface) exitWith {};
    {
        if (_x getVariable ["FADE_build_placed", false]) then {
            [_x] call FAC_build_clientAddRemove;
        };
    } forEach vehicles;
};

missionNamespace setVariable ["FADE_build_findEntry", FADE_build_findEntry];
missionNamespace setVariable ["FADE_build_signClean", FADE_build_signClean];
missionNamespace setVariable ["FADE_build_signTexture", FADE_build_signTexture];
missionNamespace setVariable ["FADE_build_writeSlot", FADE_build_writeSlot];
missionNamespace setVariable ["FADE_build_spotBlocked", FADE_build_spotBlocked];
missionNamespace setVariable ["FAC_build_clientAddRemove", FAC_build_clientAddRemove];
missionNamespace setVariable ["FAC_build_clientScan", FAC_build_clientScan];
