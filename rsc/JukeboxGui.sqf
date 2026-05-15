// =============================================================================
// JukeboxGui.sqf -- Jukebox: loudspeaker tracks (per client, per source)
// =============================================================================
// Sources: radio:Radio_1..4 (Eden) use playSound3D (fixed world position at emitters). vehicle:<netId> uses
//   createSoundSource (CfgVehicles FAC_Jukebox_<CfgSounds name>) + attachTo — playSound3D does not move with objects.
// Each source has at most one track; different sources may play simultaneously.
// Stop all music: Scenario → Admin only (FAC_jukebox_stopAllMusic → FAC_jukebox_clientStopAll on all clients).
// Client Play -> server validates emitter + CfgSounds, updates FAC_jukebox_activeSources [key, song, volume, distance],
//   remoteExec FAC_jukebox_clientPlay [song, sourceKey, volume, distance] to all clients (no JIP replay of active sources).
// Per client: queued drain (spawn) serializes jobs. Radios: playSound3D + stopSound on handle; vehicles: attached Sound + deleteVehicle.
// FAC_jukebox_clientAudioList: [sourceKey, playSound3D handle or "", attached Sound object or objNull].
// =============================================================================

// -----------------------------------------------------------------------------
// Loudspeaker track list -- [displayLabel, CfgSFX / CfgSounds classname] pairs.
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
    ["Buttrock > Breaking Benjamin - The Diary of Jane", "Sig_Buttrock_1"],
    ["Buttrock > Creed - One Last Breath",         "Sig_Buttrock_2"],
    ["Buttrock > Crossfade - Cold",                "Sig_Buttrock_3"],
    ["Buttrock > Drowning Pool - Bodies",          "Sig_Buttrock_4"],
    ["Buttrock > Kid Rock - Bawitdaba",            "Sig_Buttrock_5"],
    ["Buttrock > Limp Bizkit - Take a Look Around", "Sig_Buttrock_6"],
    ["Buttrock > Linkin Park - Somewhere I Belong", "Sig_Buttrock_7"],
    ["Buttrock > Nickelback - Savin' Me",          "Sig_Buttrock_8"],
    ["Buttrock > P.O.D. - Boom",                   "Sig_Buttrock_9"],
    ["Buttrock > Puddle of Mudd - Blurry",         "Sig_Buttrock_10"],
    ["Buttrock > Saliva - Click Click Boom",       "Sig_Buttrock_11"],
    ["Buttrock > System of a Down - Toxicity",    "Sig_Buttrock_12"],
    ["Buttrock > Staind - It's Been Awhile",       "Sig_Buttrock_13"],
    ["Buttrock > Staind - Rainy Day Parade",       "Sig_Buttrock_14"],
    ["Buttrock > Three Days Grace - Animal I Have Become", "Sig_Buttrock_15"],
    ["Buttrock > Trapt - Headstrong",              "Sig_Buttrock_16"],
    ["Buttrock > Trust Company - Downfall",        "Sig_Buttrock_17"],
    ["Buttrock > Korn - Twisted Transistor",       "Sig_Buttrock_18"],
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

// Addon .ogg paths (reference / future use). Fallback file for playSound3D when CfgSounds is missing (e.g. radios).
FAC_jukebox_oggPairs = [
    ["Sig_80smusic_mix_1",    "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\1980s\80s_mix_1.ogg"],
    ["Sig_BF2_MEC",           "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF2_MECTheme.ogg"],
    ["Sig_BF2_CHI",           "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF2_ChinaTheme.ogg"],
    ["Sig_BF1942_Menu",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF1942_MenuTheme.ogg"],
    ["Sig_BF1942_Loading1",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF1942_LoadingTheme.ogg"],
    ["Sig_BF1942_Loading2",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF1942_Vehicle3.ogg"],
    ["Sig_BFDC_Menu",         "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF1942_DesertCombatTheme.ogg"],
    ["Sig_BFDC_Loading",      "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\BF\BF1942_DesertCombatLoading.ogg"],
    ["Sig_CNC_Tibdawn_Mix",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\C&C\c&c_mix.ogg"],
    ["Sig_CNC_Gen_GLA_Mix",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\C&C\generals_gla_mix.ogg"],
    ["Sig_CNC_Gen_USA_Mix",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\C&C\generals_USA_mix.ogg"],
    ["Sig_CNC_Gen_CHI_Mix",   "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\C&C\generals_CHI_mix.ogg"],
    ["Sig_BHD_Mix",           "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\bhd_mix.ogg"],
    ["Sig_Abba_Gimmie",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Abba_Gimmie.ogg"],
    ["Sig_90sdance_Mix",      "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\90s\90sdance_mix.ogg"],
    ["Sig_OFPSeventh_mix",    "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\ofp_seventh_mix.ogg"],
    ["Sig_SovietMusic_mix_1", "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Soviet\soviet_mix_1.ogg"],
    ["Sig_VietnamMusic_mix_1","\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Vietnam\vietnam_mix_1.ogg"],
    ["Sig_Buttrock_1",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_BreakingBenjamin_TheDiaryOfJane.ogg"],
    ["Sig_Buttrock_2",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Creed_OneLastBreath.ogg"],
    ["Sig_Buttrock_3",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Crossfade_Cold.ogg"],
    ["Sig_Buttrock_4",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_DrowningPool_Bodies.ogg"],
    ["Sig_Buttrock_5",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_KidRock_Bawitdaba.ogg"],
    ["Sig_Buttrock_6",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_LimpBizkit_TakeaLookAround.ogg"],
    ["Sig_Buttrock_7",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_LinkinPark_SomewhereIBelong.ogg"],
    ["Sig_Buttrock_8",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Nickelback_SavinMe.ogg"],
    ["Sig_Buttrock_9",        "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_POD_boom.ogg"],
    ["Sig_Buttrock_10",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_PuddleofMudd_Blurry.ogg"],
    ["Sig_Buttrock_11",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_saliva_clickclickboom.ogg"],
    ["Sig_Buttrock_12",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_SOAD_Toxicity.ogg"],
    ["Sig_Buttrock_13",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Staind_ItsBeenAwhile.ogg"],
    ["Sig_Buttrock_14",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Staind_RainyDayParade.ogg"],
    ["Sig_Buttrock_15",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_ThreeDaysGrace_AnimalIHaveBecome.ogg"],
    ["Sig_Buttrock_16",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_Trapt_Headstrong.ogg"],
    ["Sig_Buttrock_17",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_TrustCompany_Downfall.ogg"],
    ["Sig_Buttrock_18",       "\Sig_CTB_MSL_Music_Loudspeaker\loudspeaker\Buttrock\buttrock_TwistedTransistor.ogg"]
];

FAC_jukebox_fnc_oggPath = {
    params ["_song"];
    private _hit = FAC_jukebox_oggPairs select { (_x select 0) == _song };
    if (_hit isEqualTo []) exitWith {""};
    (_hit select 0) select 1
};

// stopSound from scheduled context; delayed second stop helps engine release (BIKI / forum).
// playSound3D returns a numeric handle only; string handles (legacy) cannot use stopSound in current builds.
FAC_jukebox_fnc_stopPs3d = {
    params ["_id"];
    if (isNil "_id") exitWith {};
    if (_id isEqualType "") exitWith {};
    if (!(_id isEqualType 0)) exitWith {};
    stopSound _id;
    private _h = _id;
    [_h] spawn {
        params ["_x"];
        sleep 0.05;
        stopSound _x;
    };
};

// GUI defaults (sliders 1–25 / 50–2500); persisted in missionNamespace while mission runs.
FAC_jukebox_guiVolumeDefault = 4;
FAC_jukebox_guiDistanceDefault = 400;

// -----------------------------------------------------------------------------
// Debug: gated by missionNamespace FAC_jukebox_debug (initServer; publicVariable). Default off in initServer.
// -----------------------------------------------------------------------------
FAC_jukebox_dbg = {
    params ["_msg"];
    if !(missionNamespace getVariable ["FAC_jukebox_debug", false]) exitWith {};
    if (!hasInterface) exitWith {};
    systemChat ("JUKEBOX: " + _msg);
};

// Server → one client (debug chat):
FAC_jukebox_serverDbgChat = {
    if !(missionNamespace getVariable ["FAC_jukebox_debug", false]) exitWith {};
    systemChat ("JUKEBOX [server]: " + (_this select 0));
};

// -----------------------------------------------------------------------------
FAC_jukebox_fnc_resolveEmitterClient = {
    params ["_sourceKey"];
    if (_sourceKey find "radio:" == 0) exitWith {
        private _eden = _sourceKey select [6];
        missionNamespace getVariable [_eden, objNull]
    };
    if (_sourceKey find "vehicle:" == 0) exitWith {
        private _nid = _sourceKey select [8];
        if (_nid == "") exitWith {objNull};
        objectFromNetId _nid
    };
    objNull
};

FAC_jukebox_fnc_getSongForSource = {
    params ["_key"];
    if (_key == "") exitWith {""};
    private _arr = missionNamespace getVariable ["FAC_jukebox_activeSources", []];
    private _hit = _arr select { (_x select 0) == _key };
    if (_hit isEqualTo []) exitWith {""};
    (_hit select 0) select 1
};

// Resolve OGG path + pitch from CfgSounds (mission first); optional volume/distance from config when not overridden by GUI.
FAC_jukebox_fnc_soundFileFromCfg = {
    params [["_song", ""]];
    if (_song == "") exitWith {["", 1]};
    private _cfg = missionConfigFile >> "CfgSounds" >> _song;
    if (!isClass _cfg) then { _cfg = configFile >> "CfgSounds" >> _song };
    if (!isClass _cfg) exitWith {["", 1]};
    private _arr = getArray (_cfg >> "sound");
    if (count _arr < 1) exitWith {["", 1]};
    private _file = _arr select 0;
    private _pitch = if (count _arr >= 3) then { _arr select 2 } else { 1 };
    [_file, _pitch]
};

FAC_jukebox_fnc_clientClearSourceAudio = {
    params ["_sourceKey"];
    private _em = [_sourceKey] call FAC_jukebox_fnc_resolveEmitterClient;
    if (!isNull _em) then {
        private _snd = _em getVariable ["FAC_jukeboxActiveSnd", objNull];
        if (!isNull _snd) then { deleteVehicle _snd };
        _em setVariable ["FAC_jukeboxActiveSnd", nil, false];
    };

    private _list = missionNamespace getVariable ["FAC_jukebox_clientAudioList", []];
    private _keep = [];
    {
        _x params ["_k", "_ps3d", "_o"];
        if (_k == _sourceKey) then {
            [_ps3d] call FAC_jukebox_fnc_stopPs3d;
            if (!isNull _o) then { deleteVehicle _o };
        } else {
            _keep pushBack _x;
        };
    } forEach _list;
    missionNamespace setVariable ["FAC_jukebox_clientAudioList", _keep];
};

// Vehicle loudspeaker: playSound3D position is world-fixed; use mission CfgVehicles Sound FAC_Jukebox_<song> + attachTo.
// Returns true if playback started. Loudness / range = CfgSounds FAC_JukeVeh_* (description.ext; vehicle 25 / 1000 m). GUI sliders apply to radio playSound3D only.
FAC_jukebox_fnc_tryVehicleAttachedSound = {
    params [["_sourceKey", ""], ["_song", ""], ["_emitter", objNull]];
    if (_sourceKey find "vehicle:" != 0) exitWith {false};
    if (_song == "" || {isNull _emitter}) exitWith {false};
    private _cls = format ["FAC_Jukebox_%1", _song];
    if (!isClass (missionConfigFile >> "CfgVehicles" >> _cls)) exitWith {false};
    private _snd = createSoundSource [_cls, getPosATL _emitter, [], 0];
    if (isNull _snd) exitWith {false};
    _snd attachTo [_emitter, [0, 0, 0]];
    _emitter setVariable ["FAC_jukeboxActiveSnd", _snd, false];
    private _list = missionNamespace getVariable ["FAC_jukebox_clientAudioList", []];
    _list pushBack [_sourceKey, "", _snd];
    missionNamespace setVariable ["FAC_jukebox_clientAudioList", _list];
    true
};

// One playback job (must run inside spawn / scheduled - not directly from remoteExec).
FAC_jukebox_clientPlay_execOne = {
    params [["_song", ""], ["_sourceKey", ""], ["_vol", 4], ["_dist", 400]];
    if (!hasInterface) exitWith {};
    if (_sourceKey == "") exitWith {};

    [_sourceKey] call FAC_jukebox_fnc_clientClearSourceAudio;

    if (_song != "") then {
        sleep 0.06;
        private _emitter = [_sourceKey] call FAC_jukebox_fnc_resolveEmitterClient;
        if (isNull _emitter) then {
            [format ["FAIL: emitter missing for %1 - cannot play sound.", _sourceKey]] call FAC_jukebox_dbg;
        } else {
            _vol = ((round _vol) max 1) min 25;
            _dist = ((round _dist) max 50) min 2500;
            if ([_sourceKey, _song, _emitter] call FAC_jukebox_fnc_tryVehicleAttachedSound) then {
                [format ["vehicle attach OK: %1 @ %2", _song, _sourceKey]] call FAC_jukebox_dbg;
            } else {
                ([_song] call FAC_jukebox_fnc_soundFileFromCfg) params ["_file", "_pitch"];
                if (_file == "") then {
                    private _fallback = [_song] call FAC_jukebox_fnc_oggPath;
                    if (_fallback != "") then {
                        _file = _fallback;
                        _pitch = 1;
                    };
                };
                if (_file == "") then {
                    [format ["FAIL: no CfgSounds / path for %1.", _song]] call FAC_jukebox_dbg;
                } else {
                    private _pos = getPosASL _emitter;
                    private _h = playSound3D [_file, _emitter, false, _pos, _vol, _pitch, _dist];
                    if (isNil "_h" || {_h isEqualTo ""}) then {
                        [format ["FAIL: playSound3D (%1 @ %2).", _song, _sourceKey]] call FAC_jukebox_dbg;
                    } else {
                        [format ["playSound3D OK: %1 @ %2 (vol=%3 dist=%4)", _song, _sourceKey, _vol, _dist]] call FAC_jukebox_dbg;
                        private _list = missionNamespace getVariable ["FAC_jukebox_clientAudioList", []];
                        _list pushBack [_sourceKey, _h, objNull];
                        missionNamespace setVariable ["FAC_jukebox_clientAudioList", _list];
                    };
                };
            };
        };
    };

    if (!isNull (findDisplay 60400)) then {
        [format ["Client sync source %1 (song=%2)", _sourceKey, if (_song == "") then {"<none>"} else {_song}]] call FAC_jukebox_dbg;
    };

    private _guiSrc = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
    if (!isNull (findDisplay 60400) && { _sourceKey == _guiSrc }) then {
        ["updateNowPlaying", []] call FAC_jukeboxGui_fnc;
        ["updateButtons",    []] call FAC_jukeboxGui_fnc;
    };
};

// Drain queue in one spawn; exit when empty (no idle polling - dedicated server never runs this: FAC_jukebox_clientPlay requires hasInterface).
// Outer loop catches jobs appended while the last execOne runs; inner loop drains without toggling running between jobs.
FAC_jukebox_clientPlay_kickDrain = {
    // Recover if a prior drain script died with cpDrainRunning true and an empty queue (would block all jukebox RPCs).
    if (
        missionNamespace getVariable ["FAC_jukebox_cpDrainRunning", false]
        && { count (missionNamespace getVariable ["FAC_jukebox_cpQueue", []]) == 0 }
    ) then {
        missionNamespace setVariable ["FAC_jukebox_cpDrainRunning", false];
    };
    if (missionNamespace getVariable ["FAC_jukebox_cpDrainRunning", false]) exitWith {};
    missionNamespace setVariable ["FAC_jukebox_cpDrainRunning", true];
    [] spawn {
        while { true } do {
            while { count (missionNamespace getVariable ["FAC_jukebox_cpQueue", []]) > 0 } do {
                private _q = missionNamespace getVariable ["FAC_jukebox_cpQueue", []];
                private _job = _q deleteAt 0;
                missionNamespace setVariable ["FAC_jukebox_cpQueue", _q];
                _job call FAC_jukebox_clientPlay_execOne;
            };
            missionNamespace setVariable ["FAC_jukebox_cpDrainRunning", false];
            if (count (missionNamespace getVariable ["FAC_jukebox_cpQueue", []]) == 0) exitWith {};
            missionNamespace setVariable ["FAC_jukebox_cpDrainRunning", true];
        };
    };
};

// FAC_jukebox_clientPlay -- enqueue; spawn drain only when idle (no perpetual waitUntil).
// -----------------------------------------------------------------------------
FAC_jukebox_clientPlay = {
    if (!hasInterface) exitWith {};
    if (!(_this isEqualType []) || { count _this < 2 }) exitWith {};
    private _song = _this select 0;
    private _sourceKey = _this select 1;
    private _vol = _this param [2, missionNamespace getVariable ["FAC_jukebox_guiVolume", FAC_jukebox_guiVolumeDefault]];
    private _dist = _this param [3, missionNamespace getVariable ["FAC_jukebox_guiDistance", FAC_jukebox_guiDistanceDefault]];
    if (_sourceKey == "") exitWith {};

    private _q = missionNamespace getVariable ["FAC_jukebox_cpQueue", []];
    if (_song == "") then {
        _q = (_q select { (_x select 1) != _sourceKey });
        _q = [["", _sourceKey, _vol, _dist]] + _q;
    } else {
        _q pushBack [_song, _sourceKey, _vol, _dist];
    };
    missionNamespace setVariable ["FAC_jukebox_cpQueue", _q];

    [] call FAC_jukebox_clientPlay_kickDrain;
};

// Stops every jukebox source on this client (radios, all players' personal audio, queued jobs).
FAC_jukebox_clientStopAll = {
    if (!hasInterface) exitWith {};
    missionNamespace setVariable ["FAC_jukebox_cpQueue", []];
    missionNamespace setVariable ["FAC_jukebox_cpDrainRunning", false];

    private _list = missionNamespace getVariable ["FAC_jukebox_clientAudioList", []];
    {
        _x params ["_k", "_ps3d", "_o"];
        [_ps3d] call FAC_jukebox_fnc_stopPs3d;
        if (!isNull _o) then {
            private _parent = attachedTo _o;
            if (!isNull _parent) then { _parent setVariable ["FAC_jukeboxActiveSnd", nil, false] };
            deleteVehicle _o;
        };
    } forEach _list;
    missionNamespace setVariable ["FAC_jukebox_clientAudioList", []];

    {
        private _em = missionNamespace getVariable [_x, objNull];
        if (!isNull _em) then {
            private _snd = _em getVariable ["FAC_jukeboxActiveSnd", objNull];
            if (!isNull _snd) then { deleteVehicle _snd };
            _em setVariable ["FAC_jukeboxActiveSnd", nil, false];
        };
    } forEach ["Radio_1", "Radio_2", "Radio_3", "Radio_4"];
    {
        if (!isNull _x && { isPlayer _x }) then {
            private _snd = _x getVariable ["FAC_jukeboxActiveSnd", objNull];
            if (!isNull _snd) then { deleteVehicle _snd };
            _x setVariable ["FAC_jukeboxActiveSnd", nil, false];
        };
    } forEach allPlayers;

    if (!isNull (findDisplay 60400)) then {
        ["updateNowPlaying", []] call FAC_jukeboxGui_fnc;
        ["updateButtons", []] call FAC_jukeboxGui_fnc;
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
            if ((missionNamespace getVariable ["FAC_jukebox_guiSource", ""]) == "") exitWith {
                systemChat "Jukebox: open from a radio prop or Vehicle loudspeaker (in a vehicle).";
            };
            if (!createDialog "RscDisplayJukebox") then {
                ["RESOURCE NOT FOUND."] call FAC_jukebox_dbg;
            } else {
                ["Open dialog"] call FAC_jukebox_dbg;
            };
        };

        case "onLoad": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            uinamespace setVariable ["FAC_jukeboxGui_fnc", FAC_jukeboxGui_fnc];

            ["onLoad (populating list)"] call FAC_jukebox_dbg;
            ["initJukeboxSliders", []] call FAC_jukeboxGui_fnc;
            ["filter",          []] call FAC_jukeboxGui_fnc;
            ["updateNowPlaying",[]] call FAC_jukeboxGui_fnc;
            ["updateButtons",   []] call FAC_jukeboxGui_fnc;
        };

        case "initJukeboxSliders": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _v = missionNamespace getVariable ["FAC_jukebox_guiVolume", FAC_jukebox_guiVolumeDefault];
            private _d = missionNamespace getVariable ["FAC_jukebox_guiDistance", FAC_jukebox_guiDistanceDefault];
            private _sv = _disp displayCtrl 60411;
            private _sd = _disp displayCtrl 60414;
            _sv sliderSetRange [1, 25];
            _sd sliderSetRange [50, 2500];
            _sv sliderSetPosition _v;
            _sd sliderSetPosition _d;
            // Match track list width (0.46 @ x 0.27) — description.ext may still use 0.30 until updated.
            private _p = ctrlPosition _sv;
            _sv ctrlSetPosition [0.27, _p select 1, 0.46, _p select 3];
            _sv ctrlCommit 0;
            _p = ctrlPosition _sd;
            _sd ctrlSetPosition [0.27, _p select 1, 0.46, _p select 3];
            _sd ctrlCommit 0;
            (_disp displayCtrl 60412) ctrlSetText str (round _v);
            (_disp displayCtrl 60415) ctrlSetText str (round _d);
        };

        case "volumeSliderChanged": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _sv = _disp displayCtrl 60411;
            private _v = round (sliderPosition _sv);
            _v = _v max 1 min 25;
            missionNamespace setVariable ["FAC_jukebox_guiVolume", _v];
            (_disp displayCtrl 60412) ctrlSetText str _v;
        };

        case "distanceSliderChanged": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _sd = _disp displayCtrl 60414;
            private _d = round (sliderPosition _sd);
            _d = _d max 50 min 2500;
            missionNamespace setVariable ["FAC_jukebox_guiDistance", _d];
            (_disp displayCtrl 60415) ctrlSetText str _d;
        };

        case "headerRefresh": {
            ["filter", []] call FAC_jukeboxGui_fnc;
            ["updateNowPlaying", []] call FAC_jukeboxGui_fnc;
            ["updateButtons", []] call FAC_jukeboxGui_fnc;
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

            // Re-select currently playing track if visible (this GUI source)
            private _src = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
            private _nowPlaying = [_src] call FAC_jukebox_fnc_getSongForSource;
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
            if (_sel < 0) exitWith { ["Select a track first."] call FAC_jukebox_dbg };
            private _class = _lb lbData _sel;
            if (_class == "") exitWith { ["Play aborted (no lbData)"] call FAC_jukebox_dbg; };
            if (isNull player) exitWith { ["Play aborted (null player)"] call FAC_jukebox_dbg; };
            private _key = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
            if (_key == "") exitWith { ["No source (re-open the jukebox)."] call FAC_jukebox_dbg };
            private _vol = round (sliderPosition (_disp displayCtrl 60411));
            private _dist = round (sliderPosition (_disp displayCtrl 60414));
            _vol = _vol max 1 min 25;
            _dist = _dist max 50 min 2500;
            missionNamespace setVariable ["FAC_jukebox_guiVolume", _vol];
            missionNamespace setVariable ["FAC_jukebox_guiDistance", _dist];
            [format ["Play → server: %1 @ %2 (vol=%3 dist=%4)", _class, _key, _vol, _dist]] call FAC_jukebox_dbg;
            [_class, _key, player, _vol, _dist] remoteExec ["FAC_jukebox_serverPlay", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "stop": {
            if (isNull player) exitWith { ["Stop aborted (null player)"] call FAC_jukebox_dbg; };
            private _key = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
            if (_key == "") exitWith { ["No source (re-open the jukebox)."] call FAC_jukebox_dbg };
            ["Stop → server"] call FAC_jukebox_dbg;
            [_key] spawn {
                params ["_k"];
                [_k] call FAC_jukebox_fnc_clientClearSourceAudio;
            };
            ["", _key, player] remoteExec ["FAC_jukebox_serverPlay", 2];
            [] call (missionNamespace getVariable ["FAC_guiScheduleHeaderRefresh", {}]);
        };

        case "updateNowPlaying": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _src = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
            private _nowPlaying = [_src] call FAC_jukebox_fnc_getSongForSource;
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
            ["updateButtons", []] call FAC_jukeboxGui_fnc;
        };

        case "updateButtons": {
            private _disp = findDisplay 60400;
            if (isNull _disp) exitWith {};
            private _lb = _disp displayCtrl 60402;
            private _src = missionNamespace getVariable ["FAC_jukebox_guiSource", ""];
            private _np = [_src] call FAC_jukebox_fnc_getSongForSource;
            (_disp displayCtrl 60404) ctrlEnable ((lbCurSel _lb >= 0) && (_np == ""));
            (_disp displayCtrl 60405) ctrlEnable (_np != "");
        };

    };
};

// Vehicle loudspeaker *menu*: [local Man] call only. addAction + ACE live on the *infantry unit* (player), not the vehicle —
// avoids scroll/distance quirks when the hull moves fast. Playback uses createSoundSource + attachTo on the vehicle netId.
// Vanilla: condition uses _target (= unit the action is on). ACE: ACE_SelfActions on same unit.
FAC_jukebox_fnc_addVehicleLoudspeakerAction = {
    params [["_u", objNull]];
    if (isNull _u) then { _u = player };
    if (isNull _u || {!local _u} || {!(_u isKindOf "Man")}) exitWith {};

    private _aid = _u getVariable ["FAC_jukebox_vehLsAid", -1];
    if (_aid >= 0) then { _u removeAction _aid };
    _aid = _u addAction [
        "Vehicle loudspeaker...",
        {
            private _veh = vehicle player;
            if (_veh isEqualTo player) exitWith {};
            missionNamespace setVariable ["FAC_jukebox_guiSource", format ["vehicle:%1", netId _veh]];
            [] spawn { sleep 0.2; ["open", []] call FAC_jukeboxGui_fnc };
        },
        [],
        5,
        false,
        false,
        "",
        "!((vehicle _target) isEqualTo _target)",
        3
    ];
    _u setVariable ["FAC_jukebox_vehLsAid", _aid, false];

    if (!isNil "ace_interact_menu_fnc_createAction" && {!(_u getVariable ["FAC_jukebox_aceVehLsAdded", false])}) then {
        private _aceAct = [
            "FAC_juke_vehicle_ls",
            "Vehicle loudspeaker...",
            "",
            {
                private _veh = vehicle player;
                if (_veh isEqualTo player) exitWith {};
                missionNamespace setVariable ["FAC_jukebox_guiSource", format ["vehicle:%1", netId _veh]];
                [] spawn { sleep 0.2; ["open", []] call FAC_jukeboxGui_fnc };
            },
            { !((vehicle player) isEqualTo player) }
        ] call ace_interact_menu_fnc_createAction;
        [_u, 1, ["ACE_SelfActions"], _aceAct] call ace_interact_menu_fnc_addActionToObject;
        _u setVariable ["FAC_jukebox_aceVehLsAdded", true, false];
    };
};

// GetIn/GetOut on the *unit* (not vehicle): refresh vanilla addAction; EHs stay on Man for same reason as above.
FAC_jukebox_fnc_installVehicleLoudspeakerHandlers = {
    params [["_u", player]];
    if (isNull _u || {!local _u} || {!(_u isKindOf "Man")}) exitWith {};
    private _in = _u getVariable ["FAC_jukebox_ehGetIn", -1];
    private _out = _u getVariable ["FAC_jukebox_ehGetOut", -1];
    if (_in >= 0) then { _u removeEventHandler ["GetInMan", _in] };
    if (_out >= 0) then { _u removeEventHandler ["GetOutMan", _out] };
    _in = _u addEventHandler ["GetInMan", { params ["_unit"]; [_unit] call FAC_jukebox_fnc_addVehicleLoudspeakerAction }];
    _out = _u addEventHandler ["GetOutMan", { params ["_unit"]; [_unit] call FAC_jukebox_fnc_addVehicleLoudspeakerAction }];
    _u setVariable ["FAC_jukebox_ehGetIn", _in, false];
    _u setVariable ["FAC_jukebox_ehGetOut", _out, false];
};
