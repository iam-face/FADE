// ServerWorldPlacementConsts.sqf - map bounds and LZ/troop distance tunables
// Map bounds for mission spawns (min/max X and Y); playable area 0..30000 on current terrain
FADE_mapMin = 0;
FADE_mapMax = 30000;
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
