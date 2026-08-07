// =============================================================================
// onPlayerRespawn.sqf -- runs on the local client after each respawn
// =============================================================================
// When respawn is enabled (e.g. via in-game menu): restore respawn snapshot (mission
// spawn gear captured once, or loadout box "Save my loadout" which overwrites that).
// =============================================================================

// Brief yield so the engine finishes spawning the unit before we move/overwrite gear
sleep 0.1;

if (isNil "FAC_ensureLoadoutGui") then { call compile preprocessFileLineNumbers "rsc\FAC_ClientGuiEnsure.sqf"; };
call FAC_ensureLoadoutGui;
call FAC_ensureJukeboxGui;

// Keep mission ownership/UI variables across respawn so abort and mission details remain available.
params [["_newUnit", objNull], ["_oldUnit", objNull]];
if (isNull _newUnit) then { _newUnit = player };

// Eden respawn unit is slot-side (usually WEST); server joinSilent onto FADE_sideFriendly if needed.
if (!isNull _newUnit && { isPlayer _newUnit }) then {
    [_newUnit] remoteExec ["FADE_requestScenarioFriendlySideSync", 2];
};
if (!isNull _oldUnit) then {
    {
        private _val = _oldUnit getVariable [_x, nil];
        if (!isNil "_val") then { _newUnit setVariable [_x, _val, true] };
    } forEach ["FADE_myMission", "FADE_myMissionTaskId", "FADE_myMissionMarker", "FADE_myMissionMarkerEnd", "FADE_myMissionBrief"];
};

if (!isNil "FAC_loadoutGui_restoreRespawnLoadoutSnapshot") then {
    private _uid = getPlayerUID player;
    if (count (missionNamespace getVariable ["FAC_savedLoadout_" + _uid, []]) > 0) then {
        [player] call FAC_loadoutGui_restoreRespawnLoadoutSnapshot;
    } else {
        if (!isNil "FAC_loadoutGui_trySaveInitialRespawnLoadoutIfMissing") then {
            [player] call FAC_loadoutGui_trySaveInitialRespawnLoadoutIfMissing;
        };
    };
};

if (!isNil "FAC_jukebox_fnc_addVehicleLoudspeakerAction") then {
    [player] call FAC_jukebox_fnc_addVehicleLoudspeakerAction;
};
if (!isNil "FAC_jukebox_fnc_installVehicleLoudspeakerHandlers") then {
    [player] call FAC_jukebox_fnc_installVehicleLoudspeakerHandlers;
};

// FIRES fall-of-shot: Fired EH is on the unit; re-attach after respawn so mortar tracking keeps working.
if (!isNil "FAC_firesFoS_fnc_client_installFiresFiredEh") then {
    [player] call FAC_firesFoS_fnc_client_installFiresFiredEh;
};
