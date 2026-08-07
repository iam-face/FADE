// ServerWorldPlacementConsts.sqf - map bounds and LZ/troop distance tunables
// Map playable rectangle: prefer Eden logics FADE_Corner_1..4 (AABB); else 0..worldSize.
// Independent X/Y (FADE_mapMinX/MaxX/MinY/MaxY). FADE_mapMin/Max = envelope for legacy readers.

FADE_mapCornerNames = ["FADE_Corner_1", "FADE_Corner_2", "FADE_Corner_3", "FADE_Corner_4"];

FADE_resolveMapBounds = {
    private _ws = worldSize;
    private _minX = 0;
    private _maxX = _ws;
    private _minY = 0;
    private _maxY = _ws;
    private _names = missionNamespace getVariable ["FADE_mapCornerNames", FADE_mapCornerNames];
    private _xs = [];
    private _ys = [];
    {
        private _o = missionNamespace getVariable [_x, objNull];
        if (!isNull _o) then {
            private _p = getPosATL _o;
            _xs pushBack (_p select 0);
            _ys pushBack (_p select 1);
        };
    } forEach _names;

    private _src = "worldSize";
    if (count _xs >= 2) then {
        private _cMinX = selectMin _xs;
        private _cMaxX = selectMax _xs;
        private _cMinY = selectMin _ys;
        private _cMaxY = selectMax _ys;
        if (_cMaxX > _cMinX && { _cMaxY > _cMinY }) then {
            _minX = _cMinX;
            _maxX = _cMaxX;
            _minY = _cMinY;
            _maxY = _cMaxY;
            _src = format ["FADE_Corner_* (%1)", count _xs];
        } else {
            diag_log format ["[FADE] Map corners degenerate (%1 pts); using 0..worldSize (%2).", count _xs, _ws];
        };
    } else {
        if (count _xs > 0) then {
            diag_log format ["[FADE] Need >=2 FADE_Corner_* logics (found %1); using 0..worldSize (%2).", count _xs, _ws];
        };
    };

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
        "[FADE] Map bounds from %1: X %2..%3, Y %4..%5 (legacy envelope %6..%7).",
        _src, FADE_mapMinX, FADE_mapMaxX, FADE_mapMinY, FADE_mapMaxY, FADE_mapMin, FADE_mapMax
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
