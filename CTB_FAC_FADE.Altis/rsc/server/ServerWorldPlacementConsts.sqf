// ServerWorldPlacementConsts.sqf - map bounds and LZ/troop distance tunables
// Playable rectangle is the terrain square, 0..worldSize on X and Y.
// Eden FADE_Corner_* logics are not read. Delete them from the mission.
// FADE_mapMin/Max = envelope for legacy readers.

FADE_resolveMapBounds = {
    private _ws = worldSize;
    private _minX = 0;
    private _maxX = _ws;
    private _minY = 0;
    private _maxY = _ws;

    FADE_mapMinX = _minX;
    FADE_mapMaxX = _maxX;
    FADE_mapMinY = _minY;
    FADE_mapMaxY = _maxY;
    // Legacy single-axis envelope (same clamp on X and Y) — prefer MinX/MaxX/MinY/MaxY.
    FADE_mapMin = _minX min _minY;
    FADE_mapMax = _maxX max _maxY;

    missionNamespace setVariable ["FADE_mapMinX", FADE_mapMinX];
    missionNamespace setVariable ["FADE_mapMaxX", FADE_mapMaxX];
    missionNamespace setVariable ["FADE_mapMinY", FADE_mapMinY];
    missionNamespace setVariable ["FADE_mapMaxY", FADE_mapMaxY];
    missionNamespace setVariable ["FADE_mapMin", FADE_mapMin];
    missionNamespace setVariable ["FADE_mapMax", FADE_mapMax];

    diag_log format [
        "[FADE] Map bounds from worldSize: X %1..%2, Y %3..%4 (legacy envelope %5..%6).",
        FADE_mapMinX, FADE_mapMaxX, FADE_mapMinY, FADE_mapMaxY, FADE_mapMin, FADE_mapMax
    ];
};

// True if [x,y,...] lies inside the playable rectangle.
FADE_mapPosInBounds = {
    params ["_pos"];
    if (count _pos < 2) exitWith { false };
    private _sx = _pos select 0;
    private _sy = _pos select 1;
    (_sx >= FADE_mapMinX) && { _sx <= FADE_mapMaxX } && { _sy >= FADE_mapMinY } && { _sy <= FADE_mapMaxY }
};
missionNamespace setVariable ["FADE_mapPosInBounds", FADE_mapPosInBounds];

// Clamp a 2D [x,y] (or longer) inward by optional pad; returns [x,y] (z dropped).
FADE_mapClampPos2D = {
    params ["_xy", ["_pad", 0]];
    if (count _xy < 2) exitWith { [FADE_mapMinX, FADE_mapMinY] };
    private _padX = _pad min ((FADE_mapMaxX - FADE_mapMinX) / 2);
    private _padY = _pad min ((FADE_mapMaxY - FADE_mapMinY) / 2);
    [
        ((_xy select 0) max (FADE_mapMinX + _padX) min (FADE_mapMaxX - _padX)),
        ((_xy select 1) max (FADE_mapMinY + _padY) min (FADE_mapMaxY - _padY))
    ]
};
missionNamespace setVariable ["FADE_mapClampPos2D", FADE_mapClampPos2D];
missionNamespace setVariable ["FADE_resolveMapBounds", FADE_resolveMapBounds];

call FADE_resolveMapBounds;

FADE_minDistFromBase = 700;
// Troop Insert LZ and Troop Extract pickup: minimum distance from FADE_basePos (meters)
FADE_troopInsertExtractMinDistFromBase = 2000;
FADE_troopInsertPickupMinDist = 500;           // fresh squad link-up: min offset from transport
FADE_troopInsertPickupMaxDist = 1000;          // fresh squad link-up: max offset from transport
FADE_troopInsertLzMinDistFromPickup = 2500;    // insert LZ must be at least this far from link-up
FADE_troopHeliSiteMaxDistFromCivZone = 250;    // insert/extract LZ/pickup must be within this of a civ zone centre
FADE_troopInsertWaveTimeout = 620;             // max seconds to wait for slowest transport in a wave
// Heli LZ search (FADE_findSafeLZ): loose rules — marker hints area; pilots pick the actual landing spot
FADE_lzClearanceM = 5;                         // min clearance from buildings/walls (trees/bushes allowed closer)
FADE_lzMaxGrad = 0.5;                        // max terrain slope (BIS findSafePos; higher = steeper OK)
FADE_lzSearchRadiusDefault = 80;              // default search disc when caller omits radius
FADE_lzLocalSearchM = 25;                    // findSafePos radius around each random attempt point
FADE_lzMaxAttempts = 30;                      // placement attempts before giving up
FADE_lzBlockObjectTypes = ["Building", "House", "Wall"]; // hard-block only structures, not vegetation
