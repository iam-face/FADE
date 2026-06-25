// =============================================================================
// FADE_MissionSlots.sqf  -  packed mission slot sync (server publish / client apply)
// =============================================================================

FADE_hqMainBoard_sanitizeTextureText = {
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

FADE_hqMainBoard_missionTypeDisplayName = {
    params [["_missionType", ""]];
    private _displayName = _missionType;
    private _displayNameFnc = missionNamespace getVariable ["FADE_missionTypeDisplayName", {}];
    if (_displayNameFnc isEqualType {}) then {
        _displayName = [_missionType] call _displayNameFnc;
    };
    if (_displayName == _missionType) then {
        private _fallbackLabels = [
            ["AreaOfOperations", "Area of Operations"],
            ["AssetRetrieval", "Asset Retrieval"],
            ["CAS", "CAS / Fire Support"],
            ["ClearArea", "Clear Area"],
            ["CSAR", "CSAR"],
            ["EscapeEvasion", "Escape & Evasion"],
            ["Hostage", "Hostage"],
            ["HVT", "HVT"],
            ["InterceptConvoy", "Intercept Convoy"],
            ["Operation", "Operation"],
            ["SearchDestroy", "Search & Destroy"]
        ];
        { if ((_x select 0) == _missionType) exitWith { _displayName = _x select 1 } } forEach _fallbackLabels;
    };
    _displayName
};

FADE_hqMainBoard_buildTexture = {
    params [["_globalMission", []]];
    private _body = "\n\nTODAY'S MISSION\n\nNo Mission Active";
    if (_globalMission isEqualType [] && { count _globalMission >= 5 }) then {
        private _missionType = _globalMission param [0, ""];
        private _operationName = _globalMission param [4, ""];
        private _missionTypeName = [_missionType] call FADE_hqMainBoard_missionTypeDisplayName;
        _body = format [
            "\n\nTODAY'S MISSION\n\n%1\n\n%2",
            [_operationName] call FADE_hqMainBoard_sanitizeTextureText,
            [_missionTypeName] call FADE_hqMainBoard_sanitizeTextureText
        ];
    };
    format [
        "#(rgb,512,512,1)text(0,1,""TahomaB"",0.05,""#000000"",""#FFFFFF"",""%1"")",
        _body
    ]
};

FADE_hqMainBoard_update = {
    if (!isServer) exitWith {};
    private _board = missionNamespace getVariable ["hqMainBoard", objNull];
    if (isNull _board) exitWith {};
    private _texture = [missionNamespace getVariable ["FADE_globalMission", []]] call FADE_hqMainBoard_buildTexture;
    _board setObjectTextureGlobal [0, _texture];
};

FADE_missionSlots_publish = {
    if (!isServer) exitWith {};
    private _pack = [
        "v1",
        + (missionNamespace getVariable ["FADE_globalMission", []]),
        + (missionNamespace getVariable ["FADE_singleMissions", []]),
        missionNamespace getVariable ["FADE_currentMissionType", ""],
        missionNamespace getVariable ["FADE_currentMissionPlayer", objNull]
    ];
    missionNamespace setVariable ["FADE_missionSlotsSync", _pack, true];
    publicVariable "FADE_missionSlotsSync";
    [] call FADE_hqMainBoard_update;
};

FADE_missionSlots_set = {
    if (!isServer) exitWith {};
    params [
        ["_global", nil],
        ["_singles", nil],
        ["_currentType", nil],
        ["_currentPlayer", nil]
    ];
    if (!isNil "_global") then {
        missionNamespace setVariable ["FADE_globalMission", _global];
    };
    if (!isNil "_singles") then {
        missionNamespace setVariable ["FADE_singleMissions", _singles];
    };
    if (!isNil "_currentType") then {
        missionNamespace setVariable ["FADE_currentMissionType", _currentType];
    };
    if (!isNil "_currentPlayer") then {
        missionNamespace setVariable ["FADE_currentMissionPlayer", _currentPlayer];
    };
    [] call FADE_missionSlots_publish;
};

FADE_applyMissionSlotsClientSync = {
    params ["_pack"];
    if (!hasInterface) exitWith {};
    if (!(_pack isEqualType []) || { count _pack < 5 }) exitWith {};
    if ((_pack select 0) != "v1") exitWith {};
    _pack params ["_ver", "_global", "_singles", "_curType", "_curPlayer"];
    missionNamespace setVariable ["FADE_globalMission", _global];
    missionNamespace setVariable ["FADE_singleMissions", _singles];
    missionNamespace setVariable ["FADE_currentMissionType", _curType];
    missionNamespace setVariable ["FADE_currentMissionPlayer", _curPlayer];
};

missionNamespace setVariable ["FADE_missionSlots_publish", FADE_missionSlots_publish];
missionNamespace setVariable ["FADE_missionSlots_set", FADE_missionSlots_set];
missionNamespace setVariable ["FADE_applyMissionSlotsClientSync", FADE_applyMissionSlotsClientSync];
missionNamespace setVariable ["FADE_hqMainBoard_update", FADE_hqMainBoard_update];
