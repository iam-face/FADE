// =============================================================================
// onPlayerRespawn.sqf -- runs on the local client after each respawn
// =============================================================================
// When respawn is enabled (e.g. via in-game menu): force position to base and
// restore saved loadout if the player used "Save my loadout" at the loadout box.
// =============================================================================

// Brief yield so the engine finishes spawning the unit before we move/overwrite gear
sleep 0.1;

// Keep mission ownership/UI variables across respawn so abort and mission details remain available.
params [["_newUnit", objNull], ["_oldUnit", objNull]];
if (isNull _newUnit) then { _newUnit = player };
if (!isNull _oldUnit) then {
    {
        private _val = _oldUnit getVariable [_x, nil];
        if (!isNil "_val") then { _newUnit setVariable [_x, _val, true] };
    } forEach ["FADE_myMission", "FADE_myMissionTaskId", "FADE_myMissionMarker", "FADE_myMissionMarkerEnd", "FADE_myMissionBrief"];
};

private _savedLoadout = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
if (count _savedLoadout > 0) then {
    player setUnitLoadout _savedLoadout;
};
