// =============================================================================
// JukeboxGui.sqf -- Radio_1 jukebox: CTB loudspeaker tracks via say3D
// =============================================================================
// Playback architecture:
//   Client presses Play -> [class] remoteExec ["FAC_jukebox_serverPlay", 2]
//   Server stores nowPlaying state (publicVariable) and remoteExec
//     ["FAC_jukebox_clientPlay", 0] to all clients (with JIP key).
//   Each client runs FAC_jukebox_clientPlay:
//     - deleteVehicle on any existing local sound object (stops previous track)
//     - _radio say3D [_class, 300, 1] -> returns a #soundonvehicle object
//     - stores that object in FAC_jukebox_soundObj for later stop
//   Stop: server broadcasts clientPlay with "" -> each client deleteVehicle
// =============================================================================

// -----------------------------------------------------------------------------
// CTB loudspeaker track list -- [displayLabel, classname] pairs.
// Labels derived from the CfgSFX "name" property (format "Group\Track Name").
// -----------------------------------------------------------------------------
FAC_jukebox_tracks = [
    ["80s > 80s Mix",                   "Sig_80smusic_mix_1"],
    ["Battlefield > BF1942 Desert Combat Loading", "Sig_BFDC_Loading"],
    ["Battlefield > BF1942 Desert Combat Theme",   "Sig_BFDC_Menu"],
    ["Battlefield > BF1942 Loading Theme",         "Sig_BF1942_Loading1"],
    ["Battlefield > BF1942 Vehicle Theme",         "Sig_BF1942_Loading2"],
    ["Battlefield > BF1942 Menu Theme",            "Sig_BF1942_Menu"],
    ["Battlefield > BF2 China Theme",              "Sig_BF2_CHI"],
    ["Battlefield > BF2 MEC Theme",                "Sig_BF2_MEC"],
    ["Black Hawk Down > BHD Mix",                  "Sig_BHD_Mix"],
    ["C&C > Generals China Mix",                   "Sig_CNC_Gen_CHI_Mix"],
    ["C&C > Generals GLA Mix",                     "Sig_CNC_Gen_GLA_Mix"],
    ["C&C > Generals USA Mix",                     "Sig_CNC_Gen_USA_Mix"],
    ["C&C > Tiberian Dawn Mix",                    "Sig_CNC_Tibdawn_Mix"],
    ["Classic > ABBA Gimme",                       "Sig_Abba_Gimmie"],
    ["Classic > OFP Seventh Mix",                  "Sig_OFPSeventh_mix"],
    ["Dance > 90s Dance Mix",                      "Sig_90sdance_Mix"],
    ["Soviet > Soviet Mix",                        "Sig_SovietMusic_mix_1"],
    ["Vietnam > Vietnam Mix",                      "Sig_VietnamMusic_mix_1"]
];

// -----------------------------------------------------------------------------
// FAC_jukebox_clientPlay -- runs on every client via remoteExec from server.
// Stops any existing local sound, then plays the new track from Radio_1.
// hasInterface guard prevents execution on dedicated server / headless clients.
// -----------------------------------------------------------------------------
// Helper: extract [file, volume, distance] from a CfgSFX classname.
// CfgSFX structure: sounds[] = {"sound0"}; sound0[] = {file, vol, pitch, dist, ...};
FAC_jukeboxGui_sfxFileData = {
    params ["_class"];
    private _sfxCfg    = configFile >> "CfgSFX" >> _class;
    private _propName  = (getArray (_sfxCfg >> "sounds")) select 0;
    private _arr       = getArray (_sfxCfg >> _propName);
    if (count _arr < 4) exitWith { ["", 1, 200] };
    [_arr select 0, _arr select 1, _arr select 3]
};

// -----------------------------------------------------------------------------
// FAC_jukebox_clientPlay -- runs on every client via remoteExec from server.
// Plays the track via playSound3D from Radio_1 in 3D. Audio plays to natural
// completion; there is no mid-track stop API in this Arma version.
// hasInterface guard prevents execution on dedicated server / headless clients.
// -----------------------------------------------------------------------------
FAC_jukebox_clientPlay = {
    params [["_song", ""]];
    if (!hasInterface) exitWith {};

    // --- Play new track ---
    // Note: playSound3D has no stop API in this Arma version. Pressing Stop or
    // switching tracks clears state and blocks JIP, but the current audio plays
    // to natural completion. The helper object is kept for position reference only.
    if (_song != "") then {
        private _radio = missionNamespace getVariable ["Radio_1", objNull];
        if (isNull _radio) exitWith { systemChat "JUKEBOX: Radio_1 not found."; };

        private _data = [_song] call FAC_jukeboxGui_sfxFileData;
        _data params ["_file", "_vol", "_dist"];
        if (_file == "") exitWith { systemChat format ["JUKEBOX: No audio file for %1", _song]; };

        playSound3D [_file, _radio, false, getPosASL _radio, _vol, 1, _dist];
    };

    // Update local state and refresh any open GUI
    missionNamespace setVariable ["FAC_jukebox_nowPlaying", _song];
    if (!isNull (findDisplay 60400)) then {
        ["updateNowPlaying", []] call FAC_jukeboxGui_fnc;
        ["updateButtons",    []] call FAC_jukeboxGui_fnc;
    };
};

// -----------------------------------------------------------------------------
// FAC_jukeboxGui_fnc -- dispatcher (mirrors VehicleGui / MissionsGui pattern)
// -----------------------------------------------------------------------------
FAC_jukeboxGui_fnc = {
    params ["_action", "_params"];
    private _display = findDisplay 60400;
    if (isNull _display && { _action != "open" }) exitWith {};

    switch _action do {

        case "open": {
            if (!createDialog "RscDisplayJukebox") then {
                systemChat "JUKEBOX: RESOURCE NOT FOUND.";
            };
        };

        case "onLoad": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            uinamespace setVariable ["FAC_jukeboxGui_fnc", FAC_jukeboxGui_fnc];

            ["filter",          []] call FAC_jukeboxGui_fnc;
            ["updateNowPlaying",[]] call FAC_jukeboxGui_fnc;
            ["updateButtons",   []] call FAC_jukeboxGui_fnc;
        };

        case "filter": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _searchEdit = _disp displayCtrl 60401;
            private _lb         = _disp displayCtrl 60402;
            private _searchText = toLower (ctrlText _searchEdit);

            lbClear _lb;
            {
                _x params ["_label", "_class"];
                private _pass = true;
                if (_searchText != "") then { _pass = (toLower _label) find _searchText >= 0; };
                if (_pass) then {
                    private _idx = _lb lbAdd _label;
                    _lb lbSetData [_idx, _class];
                };
            } forEach FAC_jukebox_tracks;

            // Re-select currently playing track if visible
            private _nowPlaying = missionNamespace getVariable ["FAC_jukebox_nowPlaying", ""];
            if (_nowPlaying != "") then {
                for "_i" from 0 to (lbSize _lb - 1) do {
                    if ((_lb lbData _i) == _nowPlaying) exitWith { _lb lbSetCurSel _i };
                };
            };
            ["updateButtons", []] call FAC_jukeboxGui_fnc;
        };

        case "play": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _lb  = _disp displayCtrl 60402;
            private _sel = lbCurSel _lb;
            if (_sel < 0) exitWith { systemChat "JUKEBOX: Select a track first." };
            private _class = _lb lbData _sel;
            if (_class == "") exitWith {};
            [_class] remoteExec ["FAC_jukebox_serverPlay", 2];
        };

        case "updateNowPlaying": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _nowPlaying = missionNamespace getVariable ["FAC_jukebox_nowPlaying", ""];
            private _label = "-- Nothing --";
            if (_nowPlaying != "") then {
                private _match = FAC_jukebox_tracks select { (_x select 1) == _nowPlaying };
                if (count _match > 0) then {
                    _label = (_match select 0) select 0;
                } else {
                    _label = _nowPlaying;
                };
            };
            (_disp displayCtrl 60403) ctrlSetText _label;
        };

        case "updateButtons": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _lb = _disp displayCtrl 60402;
            (_disp displayCtrl 60404) ctrlEnable (lbCurSel _lb >= 0);
        };

    };
};
