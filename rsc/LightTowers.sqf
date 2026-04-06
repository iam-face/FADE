// =============================================================================
// LightTowers.sqf -- Invisible ambient lights above pads, vehicle spawns, LOADOUTBOX, SR_Light
// =============================================================================
// Runs on each client (spawned from initPlayerLocal). createVehicleLocal ensures lights
// exist only on the local machine; no network sync. Waits for server-replicated
// FADE_helipads, FADE_vehiclePoints, FADE_loadoutBox before creating lights.
// =============================================================================

waitUntil {
    sleep 0.05;
    !isNil "FADE_helipads" && !isNil "FADE_vehiclePoints" && !isNil "FADE_loadoutBox"
};

private _heightAbovePad = 25;

// Collect all pad/vehicle spawn objects + LOADOUTBOX + SR_Light
private _padObjects = [];
if (!isNil "FADE_helipads" && { FADE_helipads isEqualType [] }) then {
    _padObjects append (FADE_helipads select { !isNull _x });
};
if (!isNil "FADE_vehiclePoints" && { FADE_vehiclePoints isEqualType [] }) then {
    _padObjects append (FADE_vehiclePoints select { !isNull _x });
};
if (!isNil "FADE_loadoutBox" && { !isNull FADE_loadoutBox }) then {
    _padObjects pushBack FADE_loadoutBox;
};
private _srLight = missionNamespace getVariable ["SR_Light", objNull];
if (!isNull _srLight) then {
    _padObjects pushBack _srLight;
};
{
    private _extraObj = missionNamespace getVariable [_x, objNull];
    if (!isNull _extraObj) then {
        _padObjects pushBack _extraObj;
    };
} forEach [
    "firesTruckSpawnPos",
    "cqbLightPos",
    "specialistLightPos",
    "specialistLightPos_1"
];

{
    private _pad = _x;
    if (isNull _pad) then { continue };

    // Position 25m above pad centre
    private _pos = (getPosATL _pad) vectorAdd [0, 0, _heightAbovePad];

    // Create omnidirectional ambient light (invisible, no collision by default)
    private _light = "#lightpoint" createVehicleLocal _pos;

    // Warm white ambient light
    _light setLightColor [1, 0.95, 0.9];
    _light setLightAmbient [0.2, 0.19, 0.18];

    // Intensity and attenuation: [start, constant, linear, quadratic, hardlimitstart, hardlimitend]
    _light setLightIntensity 5;
    _light setLightAttenuation [0, 0, 0.0004, 0.0004, 60, 100];

    // No visible flare -- fully invisible
    _light setLightUseFlare false;

} forEach _padObjects;
