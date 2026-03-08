// =============================================================================
// onPlayerRespawn.sqf -- runs on the local client after each respawn
// =============================================================================
// When respawn is enabled (e.g. via in-game menu): force position to base and
// restore saved loadout if the player used "Save my loadout" at the loadout box.
// =============================================================================

// Brief yield so the engine finishes spawning the unit before we move/overwrite gear
sleep 0.1;

private _savedLoadout = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
if (count _savedLoadout > 0) then {
    player setUnitLoadout _savedLoadout;
};
