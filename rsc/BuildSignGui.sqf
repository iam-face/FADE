// BuildSignGui.sqf - text entry for a placed piece that has a texture slot.
// The server writes the highest slot. This dialog only sends the typed text.

FAC_buildSignGui_IDD = 60970;

FAC_buildSignGui_fnc = {
    params ["_action", ["_params", []]];
    switch _action do {
        case "open": {
            if !( ["FAC_playerCanBuild"] call FAC_lobbyParams_callAccess ) exitWith {
                systemChat "You can't write with the current lobby settings.";
            };
            private _obj = (missionNamespace getVariable ["FAC_build_signNetId", ""]) call BIS_fnc_objectFromNetId;
            if (isNull _obj || { !alive _obj }) exitWith { systemChat "That piece is gone." };
            if (!isNull (findDisplay FAC_buildSignGui_IDD)) exitWith {};
            if (!createDialog "RscDisplayBuildSign") then {
                systemChat "SIGN GUI: RESOURCE NOT FOUND.";
            };
        };
        case "onLoad": {
            private _d = findDisplay FAC_buildSignGui_IDD;
            if (isNull _d) exitWith {};
            [_d, FAC_gui_spec_buildSign] call FAC_gui_build;
            private _obj = (missionNamespace getVariable ["FAC_build_signNetId", ""]) call BIS_fnc_objectFromNetId;
            private _cur = if (isNull _obj) then { "" } else { _obj getVariable ["FADE_build_signText", ""] };
            private _edit = _d displayCtrl 60971;
            if (!isNull _edit) then { _edit ctrlSetText _cur };
        };
        case "write";
        case "clear": {
            private _d = findDisplay FAC_buildSignGui_IDD;
            if (isNull _d) exitWith {};
            private _text = "";
            if (_action == "write") then {
                private _edit = _d displayCtrl 60971;
                if (!isNull _edit) then { _text = ctrlText _edit };
            };
            private _netId = missionNamespace getVariable ["FAC_build_signNetId", ""];
            if (_netId == "") exitWith { systemChat "That piece is gone." };
            [player, _netId, _text] remoteExec ["FADE_build_signSet", 2];
            closeDialog 0;
        };
    };
};

missionNamespace setVariable ["FAC_buildSignGui_fnc", FAC_buildSignGui_fnc];
