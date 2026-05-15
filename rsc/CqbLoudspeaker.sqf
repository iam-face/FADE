// =============================================================================
// CqbLoudspeaker.sqf - CQB killhouse loudspeaker 3D SFX (client)
// =============================================================================
// Server calls: [_mode] remoteExec ["FAC_cqbLoudspeaker_clientPlay", 0]
//   _mode: "start" | "stop"  → CfgSounds FAC_cqbLoudspeakerHorn
// Optional emitter: [_mode, terminalObj] remoteExec ["FAC_cqbLoudspeaker_clientPlay", 0]
//   Same horn file/vol/pitch/maxDistance; 3D origin 5 m above _emitter (firing/sniper/FIRES terminals).
// Sound: Sig_CTB_MSL_SFX_Amb - \Sig_CTB_MSL_SFX_Amb\Sounds\Alarm\alarm_2.ogg
// Origin: 5 m above Eden object cqbLoudspeaker (speaker at top of mesh).
// Same pattern as jukebox: playSound3D on each machine with hasInterface.
// =============================================================================

FAC_cqbLoudspeaker_clientPlay = {
    params [["_mode", ""], ["_emitter", objNull]];
    if (!hasInterface) exitWith {};

    private _ls = objNull;
    if (!isNull _emitter) then {
        _ls = _emitter;
    } else {
        if (!isNil "cqbLoudspeaker") then { _ls = cqbLoudspeaker };
        if (isNull _ls) then { _ls = missionNamespace getVariable ["cqbLoudspeaker", objNull] };
        if (isNull _ls) then { _ls = missionNamespace getVariable ["FADE_cqbBoard", objNull] };
        if (isNull _ls) exitWith { systemChat "CQB AUDIO: loudspeaker object not found."; };
    };

    if (!((toLower _mode) in ["start", "stop"])) exitWith {};

    private _className = "FAC_cqbLoudspeakerHorn";
    private _file = "\Sig_CTB_MSL_SFX_Amb\Sounds\Alarm\alarm_2.ogg";
    private _vol = 4;
    private _pitch = 1;
    private _dist = 2000;
    if (isClass (configFile >> "CfgSounds" >> _className)) then {
        private _arr = getArray (configFile >> "CfgSounds" >> _className >> "sound");
        if (count _arr >= 4) then {
            _file = _arr select 0;
            _vol = _arr select 1;
            _pitch = _arr select 2;
            _dist = _arr select 3;
        };
    };
    private _pos = getPosASL _ls vectorAdd [0, 0, 5];

    playSound3D [_file, _ls, false, _pos, _vol, _pitch, _dist];
};
