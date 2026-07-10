// =============================================================================
// FADE_Markers.sqf — military marker taxonomy + map grid helpers (server)
// =============================================================================

if (!isNil "FADE_markers_installed") exitWith {};
FADE_markers_installed = true;

FADE_marker_typeMap = createHashMapFromArray [
    ["objective", "mil_objective"],
    ["pickup", "mil_pickup"],
    ["warning", "mil_warning"],
    ["destroy", "mil_destroy"],
    ["flag", "mil_flag"],
    ["unknown", "mil_unknown"],
    ["dot", "mil_dot"],
    ["marker", "mil_marker"],
    ["arrow", "mil_arrow"],
    ["end", "mil_end"],
    ["attack", "mil_attack"],
    ["defend", "mil_defend"],
    ["box", "mil_box"]
];

FADE_marker_getType = {
    params [["_key", "objective"], ["_fallback", "mil_objective"]];
    private _map = missionNamespace getVariable ["FADE_marker_typeMap", createHashMap];
    _map getOrDefault [_key, _fallback]
};

FADE_map_gridCellSizeM = {
    missionNamespace getVariable ["FADE_mapGridCellSizeM", 100]
};

FADE_map_gridOriginOffset = {
    [
        missionNamespace getVariable ["FADE_mapGridOriginOffsetX", 50],
        missionNamespace getVariable ["FADE_mapGridOriginOffsetY", 50]
    ]
};

// SW corner of the map grid cell containing _pos (Altis default offset 50,50).
FADE_map_gridCellOrigin = {
    params ["_pos"];
    private _p = [_pos] call FADE_normPos3;
    private _cell = [] call FADE_map_gridCellSizeM;
    private _off = [] call FADE_map_gridOriginOffset;
    [
        (floor (((_p select 0) - (_off select 0)) / _cell)) * _cell + (_off select 0),
        (floor (((_p select 1) - (_off select 1)) / _cell)) * _cell + (_off select 1),
        0
    ]
};

// Centre of grid cell containing _pos.
FADE_map_gridCellCenter = {
    params ["_pos"];
    private _o = [_pos] call FADE_map_gridCellOrigin;
    private _cell = [] call FADE_map_gridCellSizeM;
    [(_o select 0) + (_cell * 0.5), (_o select 1) + (_cell * 0.5), 0]
};

// Unique SW corners of all map grid cells overlapping a circle.
FADE_map_gridCellsCoveringCircle = {
    params ["_center", "_radiusM"];
    private _c = [_center] call FADE_normPos3;
    private _r = _radiusM max 0;
    private _cell = [] call FADE_map_gridCellSizeM;
    private _off = [] call FADE_map_gridOriginOffset;
    private _minIx = floor (((_c select 0) - _r - (_off select 0)) / _cell);
    private _maxIx = floor (((_c select 0) + _r - (_off select 0)) / _cell);
    private _minIy = floor (((_c select 1) - _r - (_off select 1)) / _cell);
    private _maxIy = floor (((_c select 1) + _r - (_off select 1)) / _cell);
    private _out = [];
    for "_ix" from _minIx to _maxIx do {
        for "_iy" from _minIy to _maxIy do {
            private _origin = [
                (_off select 0) + (_ix * _cell),
                (_off select 1) + (_iy * _cell),
                0
            ];
            private _maxX = (_origin select 0) + _cell;
            private _maxY = (_origin select 1) + _cell;
            private _nearX = _c select 0;
            if (_nearX < (_origin select 0)) then { _nearX = _origin select 0; };
            if (_nearX > _maxX) then { _nearX = _maxX; };
            private _nearY = _c select 1;
            if (_nearY < (_origin select 1)) then { _nearY = _origin select 1; };
            if (_nearY > _maxY) then { _nearY = _maxY; };
            if (([_nearX, _nearY, 0] distance2D _c) <= _r) then {
                _out pushBackUnique _origin;
            };
        };
    };
    _out
};

FADE_map_gridCellsForSearchZone = {
    params ["_center", "_radiusM", ["_mustInclude", []]];
    private _cells = [_center, _radiusM] call FADE_map_gridCellsCoveringCircle;
    {
        if (_x isEqualType [] && { count _x >= 2 }) then {
            private _must = [_x] call FADE_map_gridCellOrigin;
            if !(_must in _cells) then { _cells pushBack _must };
        };
    } forEach _mustInclude;
    _cells
};

// One axis-aligned rectangle (map-grid snapped) covering all cells for a search zone.
// Returns [zoneCenter, [halfWidthM, halfHeightM], cellCount].
FADE_map_gridBoundsForSearchZone = {
    params ["_center", "_radiusM", ["_mustInclude", []]];
    private _cells = [_center, _radiusM, _mustInclude] call FADE_map_gridCellsForSearchZone;
    private _cell = [] call FADE_map_gridCellSizeM;
    if (count _cells == 0) then {
        _cells = [[_center] call FADE_map_gridCellOrigin];
    };
    private _minX = 1e10;
    private _maxX = -1e10;
    private _minY = 1e10;
    private _maxY = -1e10;
    {
        private _ox = _x select 0;
        private _oy = _x select 1;
        if (_ox < _minX) then { _minX = _ox; };
        if (_ox + _cell > _maxX) then { _maxX = _ox + _cell; };
        if (_oy < _minY) then { _minY = _oy; };
        if (_oy + _cell > _maxY) then { _maxY = _oy + _cell; };
    } forEach _cells;
    private _centre = [(_minX + _maxX) * 0.5, (_minY + _maxY) * 0.5, 0];
    private _halfW = (_maxX - _minX) * 0.5;
    private _halfH = (_maxY - _minY) * 0.5;
    [_centre, [_halfW, _halfH], count _cells]
};

missionNamespace setVariable ["FADE_marker_typeMap", FADE_marker_typeMap];
missionNamespace setVariable ["FADE_marker_getType", FADE_marker_getType];
missionNamespace setVariable ["FADE_map_gridCellSizeM", FADE_map_gridCellSizeM];
missionNamespace setVariable ["FADE_map_gridOriginOffset", FADE_map_gridOriginOffset];
missionNamespace setVariable ["FADE_map_gridCellOrigin", FADE_map_gridCellOrigin];
missionNamespace setVariable ["FADE_map_gridCellCenter", FADE_map_gridCellCenter];
missionNamespace setVariable ["FADE_map_gridCellsCoveringCircle", FADE_map_gridCellsCoveringCircle];
missionNamespace setVariable ["FADE_map_gridCellsForSearchZone", FADE_map_gridCellsForSearchZone];
missionNamespace setVariable ["FADE_map_gridBoundsForSearchZone", FADE_map_gridBoundsForSearchZone];
