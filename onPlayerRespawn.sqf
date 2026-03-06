// =============================================================================
// onPlayerRespawn.sqf -- runs on the local client after each respawn
// =============================================================================
// 1. Force position to base (respawn_west marker can be missed by engine; this guarantees FOB respawn).
// 2. If the player saved their loadout via the Loadout GUI (SAVE LOADOUT button),
//    that gear array is restored here. Loadout is stored in missionNamespace keyed
//    by player UID so it persists across deaths for the duration of the session.
// =============================================================================

// Brief yield so the engine finishes spawning the unit before we move/overwrite gear
sleep 0.1;

// Ensure respawn at base (heliOps_basePos is publicVariable'd from server)
if (!isNil "heliOps_basePos" && { heliOps_basePos isEqualType [] } && { count heliOps_basePos >= 2 }) then {
    private _pos = [heliOps_basePos select 0, heliOps_basePos select 1, 0];
    _pos = [_pos select 0 + (random 3 - 1.5), _pos select 1 + (random 3 - 1.5), 0];
    player setPosATL _pos;
};

private _savedLoadout = missionNamespace getVariable ["FAC_savedLoadout_" + getPlayerUID player, []];
if (count _savedLoadout > 0) then {
    player setUnitLoadout _savedLoadout;
};
