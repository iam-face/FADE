// =============================================================================
// DynamicRoadblocks.sqf -- Corridor / predictive roadblocks (server)
// =============================================================================
// Requires RoadblockCommon.sqf compiled in initServer first.
// Gated: FADE_dynamicRoadblocksEnabled && FADE_scenarioPatrols
// Active civ zones (AmbientCivilians): longest road *edge* in zone radius → midpoint + heading; one roadblock per zone id.
// When the civ zone despawns, zone-tied blocks are removed unless any human player is within FADE_dynamicRoadblockZoneGoneRetainPlayerM (default 1 km).
// Civ-zone spawn: per-zone chance (50% / 100% EE); several attempts per poll until cap. Civ blocks ignore ahead-of-player (stay in town).
// When FADE_dynamicRoadblockCivZoneOnly (default true) and any zone is active: no corridor/aggressive spawns (avoids random map roads). EE keeps corridor for route pressure.
// Otherwise: corridor + player→anchor rays + ahead filter, or aggressive spawns near players.
// =============================================================================

if (!isServer) exitWith {};

if (isNil "FADE_roadblock_spawnBundle") exitWith {
    diag_log "[FADE] DynamicRoadblocks: RoadblockCommon not loaded.";
};

private _poll = missionNamespace getVariable ["FADE_dynamicRoadblockPollSec", 14];
private _minBase = missionNamespace getVariable ["FADE_dynamicRoadblockMinDistFromBase", 1500];
private _spawnMin = missionNamespace getVariable ["FADE_dynamicRoadblockSpawnMinM", 750];
private _spawnMax = missionNamespace getVariable ["FADE_dynamicRoadblockSpawnMaxM", 2800];
private _despawnDist = missionNamespace getVariable ["FADE_dynamicRoadblockDespawnM", 3600];
private _maxActive = missionNamespace getVariable ["FADE_dynamicRoadblockMaxActive", 5];
private _minSpacing = missionNamespace getVariable ["FADE_dynamicRoadblockMinSpacingM", 450];
private _spawnChance = missionNamespace getVariable ["FADE_dynamicRoadblockSpawnChance", 0.28];
private _corridorSamples = missionNamespace getVariable ["FADE_dynamicRoadblockCorridorSamples", 7];
private _aheadMargin = missionNamespace getVariable ["FADE_dynamicRoadblockAheadMarginM", 200];
private _raySamples = missionNamespace getVariable ["FADE_dynamicRoadblockPlayerRaySamples", 5];
private _rayMaxPl = missionNamespace getVariable ["FADE_dynamicRoadblockPlayerRayMaxPlayers", 3];
private _aggMin = missionNamespace getVariable ["FADE_dynamicRoadblockAggressiveMinM", 180];
private _aggMax = missionNamespace getVariable ["FADE_dynamicRoadblockAggressiveMaxM", 950];
private _aggMinFromBase = missionNamespace getVariable ["FADE_dynamicRoadblockAggressiveMinDistFromBase", 400];
private _aggChance = missionNamespace getVariable ["FADE_dynamicRoadblockAggressiveChance", 0.34];
private _eeTMin = missionNamespace getVariable ["FADE_dynamicRoadblockEeTMin", 0.2];
private _eeTMax = missionNamespace getVariable ["FADE_dynamicRoadblockEeTMax", 0.96];
private _tDefaultMin = 0.12;
private _tDefaultMax = 0.88;
private _civZoneMode = missionNamespace getVariable ["FADE_dynamicRoadblocksCivZoneMode", true];
private _civZonePlayerMax = missionNamespace getVariable ["FADE_dynamicRoadblockCivZonePlayerMaxM", 5200];
private _civZoneSpawnMin = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneSpawnMinM", 200];
private _civZoneSpawnMax = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneSpawnMaxM", 3200];
private _civZoneChance = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneSpawnChance", 0.5];
private _civZoneChanceEe = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneSpawnChanceEe", 1];
private _civZoneOnly = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneOnly", true];

missionNamespace setVariable ["FADE_dynamicRoadblockState", missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap]];
missionNamespace setVariable ["FADE_dynamicRoadblockNextId", missionNamespace getVariable ["FADE_dynamicRoadblockNextId", 0]];

private _norm2 = {
    params ["_p"];
    if (_p isEqualType objNull) then { _p = getPosATL _p };
    if (!(_p isEqualType []) || { count _p < 2 }) exitWith { [0, 0, 0] };
    [(_p select 0), (_p select 1), (_p param [2, 0])]
};

private _rbLog = {
    params ["_msg"];
    if (missionNamespace getVariable ["FADE_checkpointDebug", false]) then {
        [format ["[DynRoadblock] %1", _msg]] remoteExec ["systemChat", 0];
    };
};

FADE_dynamicRoadblocks_despawnAll = {
    private _st = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
    {
        private _e = _st get _x;
        if (_e isEqualType [] && { count _e >= 2 }) then {
            [_e select 1] call FADE_roadblock_despawnBundle; // [center, bundle, optional zoneId]
        };
    } forEach (keys _st);
    missionNamespace setVariable ["FADE_dynamicRoadblockState", createHashMap];
};

private _eligiblePlayers = {
    private _sideF = missionNamespace getVariable ["FADE_sideFriendly", west];
    private _bp = [missionNamespace getVariable ["FADE_basePos", [0, 0, 0]]] call _norm2;
    allPlayers select {
        isPlayer _x && { alive _x } && { side group _x == _sideF } && { (_x distance2D _bp) >= _minBase }
    }
};

// Structured mission anchor (not fallback): global objective pos or EE hostile zone centre.
private _structuredCorridorEnd = {
    private _ee = missionNamespace getVariable ["FADE_dynRb_escapeZone", []];
    if (_ee isEqualType [] && { count _ee >= 2 }) exitWith {
        if (count _ee < 3) then { [(_ee select 0), (_ee select 1), 0] } else { +_ee }
    };
    private _g = missionNamespace getVariable ["FADE_globalMission", []];
    private _gt = _g param [0, ""];
    if (_gt == "Operation" || { _gt == "InterceptConvoy" }) exitWith { [] };
    private _gp = _g param [2, []];
    if (!(_gp isEqualType []) || { count _gp < 2 }) exitWith { [] };
    if (count _gp < 3) then { _gp = [(_gp select 0), (_gp select 1), 0] };
    private _bp = [missionNamespace getVariable ["FADE_basePos", [0, 0, 0]]] call _norm2;
    if ((_gp distance2D _bp) < 1200) exitWith { [] };
    _gp
};

private _fallbackEndB = {
    params ["_players"];
    if (count _players == 0) exitWith { [] };
    private _sx = 0;
    private _sy = 0;
    private _vx = 0;
    private _vy = 0;
    private _n = 0;
    {
        private _p = getPosATL _x;
        _sx = _sx + (_p select 0);
        _sy = _sy + (_p select 1);
        private _v = velocity _x;
        _vx = _vx + (_v select 0);
        _vy = _vy + (_v select 1);
        _n = _n + 1;
    } forEach _players;
    if (_n < 1) exitWith { [] };
    _sx = _sx / _n;
    _sy = _sy / _n;
    _vx = _vx / _n;
    _vy = _vy / _n;
    private _speed = sqrt (_vx * _vx + _vy * _vy);
    private _pred = if (_speed > 3) then {
        private _cap = 2500;
        private _dt = 90;
        private _dx = (_vx * _dt) min _cap max (-_cap);
        private _dy = (_vy * _dt) min _cap max (-_cap);
        [_sx + _dx, _sy + _dy, 0]
    } else {
        [_sx, _sy, 0]
    };
    private _zones = +(missionNamespace getVariable ["FADE_civTriggerNames", []]);
    private _best = [];
    private _bestD = 1e12;
    {
        private _tr = missionNamespace getVariable [_x, objNull];
        if (!isNull _tr) then {
            private _zc = getPosATL _tr;
            if (count _zc >= 2) then {
                private _d = _pred distance2D _zc;
                if (_d < _bestD) then {
                    _bestD = _d;
                    _best = if (count _zc < 3) then { [(_zc select 0), (_zc select 1), 0] } else { +_zc };
                };
            };
        };
    } forEach _zones;
    if (count _best >= 2 && { _bestD < 8500 }) exitWith { _best };
    _pred
};

private _roadsAlongCorridor = {
    params ["_a", "_b", "_n", ["_tLo", 0.12], ["_tHi", 0.88]];
    private _out = [];
    if (count _a < 2 || { count _b < 2 }) exitWith { _out };
    private _span = (_tHi - _tLo) max 0.05;
    private _i = 0;
    while { _i < _n } do {
        private _t = if (_n <= 1) then { (_tLo + _tHi) / 2 } else { _tLo + (_i / (_n - 1 max 1)) * _span };
        private _lx = (_a select 0) + ((_b select 0) - (_a select 0)) * _t;
        private _ly = (_a select 1) + ((_b select 1) - (_a select 1)) * _t;
        private _roads = [_lx, _ly, 0] nearRoads 160;
        if (count _roads > 0) then {
            private _r = selectRandom _roads;
            private _rp = getPosATL _r;
            if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
            _out pushBack _rp;
        };
        _i = _i + 1;
    };
    _out
};

// Roads near segment from player to anchor (toward objective / toward HQ for EE).
private _roadsPlayerToAnchor = {
    params ["_from", "_anchor", "_n"];
    private _out = [];
    if (count _from < 2 || { count _anchor < 2 }) exitWith { _out };
    private _i = 0;
    while { _i < _n } do {
        private _t = if (_n <= 1) then { 0.5 } else { 0.1 + (_i / (_n - 1 max 1)) * 0.8 };
        private _lx = (_from select 0) + ((_anchor select 0) - (_from select 0)) * _t;
        private _ly = (_from select 1) + ((_anchor select 1) - (_from select 1)) * _t;
        private _roads = [_lx, _ly, 0] nearRoads 150;
        if (count _roads > 0) then {
            private _r = selectRandom _roads;
            private _rp = getPosATL _r;
            if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
            _out pushBack _rp;
        };
        _i = _i + 1;
    };
    _out
};

private _dedupePositions = {
    params ["_list", ["_minSep", 130]];
    private _out = [];
    {
        private _p = _x;
        if (count _p < 2) then { } else {
            private _dup = false;
            {
                if ((_p distance2D _x) < _minSep) exitWith { _dup = true };
            } forEach _out;
            if (!_dup) then { _out pushBack _p };
        };
    } forEach _list;
    _out
};

// Longest 2D edge between connected road segments near _center → [midATL, dirDeg].
// Uses a tighter search radius (FADE_dynamicRoadblockCivZoneRoadSearchMult × _radius) so we pick streets in the town, not a long highway chord through a large ambient radius.
// If FADE_dynamicRoadblockCivZoneMidMaxM > 0, prefer edges whose midpoint is within that distance of _center; fall back to unconstrained longest if none qualify.
private _longestRoadMidInRadius = {
    params ["_center", "_radius"];
    if (count _center < 2) exitWith { [] };
    private _mult = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneRoadSearchMult", 0.55];
    private _searchR = _radius;
    if (_mult > 0 && { _mult < 1 }) then {
        _searchR = ((_radius * _mult) max 350) min _radius;
    };
    private _midMaxM = missionNamespace getVariable ["FADE_dynamicRoadblockCivZoneMidMaxM", 500];

    private _roadList = _center nearRoads _searchR;
    if (_roadList isEqualTo []) exitWith { [] };
    private _rMax = _searchR + 35;
    _roadList = _roadList select { (getPosATL _x) distance2D _center <= _rMax };
    if (_roadList isEqualTo []) exitWith { [] };

    private _pickBestEdge = {
        params ["_innerOnly", "_midMax"];
        private _bestLen = -1;
        private _bestPa = [];
        private _bestPb = [];
        {
            private _r = _x;
            private _pr = getPosATL _r;
            if (count _pr < 3) then { _pr = [(_pr select 0), (_pr select 1), 0] };
            {
                private _c = _x;
                if (_c in _roadList) then {
                    private _pc = getPosATL _c;
                    if (count _pc < 3) then { _pc = [(_pc select 0), (_pc select 1), 0] };
                    private _len = _pr distance2D _pc;
                    private _midT = [
                        ((_pr select 0) + (_pc select 0)) * 0.5,
                        ((_pr select 1) + (_pc select 1)) * 0.5,
                        ((_pr param [2, 0]) + (_pc param [2, 0])) * 0.5
                    ];
                    if (_innerOnly && { (_midT distance2D _center) > _midMax }) then { } else {
                        if (_len > _bestLen) then {
                            _bestLen = _len;
                            _bestPa = +_pr;
                            _bestPb = +_pc;
                        };
                    };
                };
            } forEach (roadsConnectedTo _r);
        } forEach _roadList;
        [_bestLen, _bestPa, _bestPb]
    };

    private _bestLen = -1;
    private _bestPa = [];
    private _bestPb = [];
    if (_midMaxM > 0) then {
        ([true, _midMaxM] call _pickBestEdge) params ["_bestLen", "_bestPa", "_bestPb"];
    };
    if (_bestLen < 3) then {
        ([false, _midMaxM] call _pickBestEdge) params ["_bestLen", "_bestPa", "_bestPb"];
    };

    if (_bestLen >= 3) exitWith {
        private _mid = [
            ((_bestPa select 0) + (_bestPb select 0)) * 0.5,
            ((_bestPa select 1) + (_bestPb select 1)) * 0.5,
            ((_bestPa param [2, 0]) + (_bestPb param [2, 0])) * 0.5
        ];
        [_mid, [_bestPa, _bestPb] call BIS_fnc_dirTo]
    };
    private _r0 = _roadList select 0;
    private _p0 = getPosATL _r0;
    if (count _p0 < 3) then { _p0 = [(_p0 select 0), (_p0 select 1), 0] };
    private _cn = roadsConnectedTo _r0;
    if (count _cn > 0) then {
        private _p1 = getPosATL (_cn select 0);
        if (count _p1 < 3) then { _p1 = [(_p1 select 0), (_p1 select 1), 0] };
        private _mid2 = [
            ((_p0 select 0) + (_p1 select 0)) * 0.5,
            ((_p0 select 1) + (_p1 select 1)) * 0.5,
            ((_p0 param [2, 0]) + (_p1 param [2, 0])) * 0.5
        ];
        [_mid2, [_p0, _p1] call BIS_fnc_dirTo]
    } else {
        [_p0, [_p0, _center] call BIS_fnc_dirTo]
    };
};

private _zoneHasRoadblock = {
    params ["_zid"];
    if (_zid isEqualTo "") exitWith { false };
    private _st = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
    private _found = false;
    {
        private _v = _st get _x;
        if (count _v >= 3) then {
            if ((_v select 2) == _zid) exitWith { _found = true };
        };
    } forEach (keys _st);
    _found
};

// True if _p is ahead of at least one player toward _anchor (closer to anchor than player).
private _aheadOfSomePlayer = {
    params ["_p", "_anchor", "_players", "_margin"];
    if (count _anchor < 2) exitWith { false };
    private _ok = false;
    {
        private _pl = getPosATL _x;
        if (count _pl < 2) then { } else {
            private _dPl = _anchor distance2D _pl;
            private _dP = _anchor distance2D _p;
            if (_dP < (_dPl - _margin)) exitWith { _ok = true };
        };
    } forEach _players;
    _ok
};

private _travelDirDeg = {
    params ["_unit"];
    private _pp = getPosATL _unit;
    private _v = velocity _unit;
    private _hm = sqrt (((_v select 0) ^ 2) + ((_v select 1) ^ 2));
    if (_hm > 1.2) then {
        private _ahead = [(_pp select 0) + (_v select 0) * 6, (_pp select 1) + (_v select 1) * 6, _pp param [2, 0]];
        if (_pp distance2D _ahead > 0.25) then {
            [_pp, _ahead] call BIS_fnc_dirTo
        } else {
            getDir _unit
        };
    } else {
        getDir _unit
    }
};

private _aggressiveRoadCandidates = {
    params ["_players", "_base"];
    private _out = [];
    private _rad = 125;
    {
        private _pl = _x;
        private _pp = getPosATL _pl;
        if (count _pp < 2) then { } else {
            private _dirM = [_pl] call _travelDirDeg;
            private _dist = _aggMin + random (_aggMax - _aggMin);
            private _aim = _pp getPos [_dist, _dirM];
            private _roads = [_aim select 0, _aim select 1, 0] nearRoads _rad;
            if (count _roads == 0) then {
                private _d2 = _dirM + 35;
                _aim = _pp getPos [_dist, _d2];
                _roads = [_aim select 0, _aim select 1, 0] nearRoads _rad;
            };
            if (count _roads == 0) then {
                private _d3 = _dirM - 35;
                _aim = _pp getPos [_dist, _d3];
                _roads = [_aim select 0, _aim select 1, 0] nearRoads _rad;
            };
            if (count _roads > 0) then {
                private _rp = getPosATL (selectRandom _roads);
                if (count _rp < 3) then { _rp = [(_rp select 0), (_rp select 1), 0] };
                if ((_rp distance2D _base) >= _aggMinFromBase) then { _out pushBack _rp };
            };
        };
    } forEach (_players call BIS_fnc_arrayShuffle);
    _out
};

private _minDistToStates = {
    params ["_pos", "_excludeId"];
    private _st = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
    private _dmin = 1e12;
    {
        private _e = _st get _x;
        if (count _e >= 1) then {
            if (_excludeId != "" && { _x == _excludeId }) then { } else {
                private _c = _e select 0;
                if (_c isEqualType []) then {
                    private _d = _pos distance2D _c;
                    if (_d < _dmin) then { _dmin = _d };
                };
            };
        };
    } forEach (keys _st);
    _dmin
};

private _spawnAt = {
    params ["_center", ["_dirOverride", -1], ["_zoneId", ""]];
    if (count _center < 3) then { _center = [(_center select 0), (_center select 1), 0] };
    private _dir = if (_dirOverride >= 0) then { _dirOverride } else { [_center, random 360] call FADE_roadblock_dirFromPos };
    private _bundle = [_center, _dir] call FADE_roadblock_spawnBundle;
    private _nid = missionNamespace getVariable ["FADE_dynamicRoadblockNextId", 0];
    private _id = format ["drb_%1", _nid];
    missionNamespace setVariable ["FADE_dynamicRoadblockNextId", _nid + 1];
    private _st = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
    _st set [_id, [_center, _bundle, _zoneId]];
    private _zNote = if (_zoneId != "") then { format [" zone %1", _zoneId] } else { "" };
    [format ["Spawned %1 grid %2.%3", _id, mapGridPosition _center, _zNote]] call _rbLog;
};

private _tryPickSpawn = {
    params ["_candidates", "_players", "_anchorAhead", "_useAheadFilter", "_base"];
    private _picked = [];
    {
        private _p = _x;
        if (count _p < 2) then { };
        if ((_p distance2D _base) >= _minBase) then {
            private _aheadOk = true;
            if (_useAheadFilter && { count _anchorAhead >= 2 }) then {
                if !([_p, _anchorAhead, _players, _aheadMargin] call _aheadOfSomePlayer) then {
                    _aheadOk = false;
                };
            };
            if (_aheadOk) then {
                private _okDist = false;
                {
                    private _d = _p distance2D (getPosATL _x);
                    if (_d >= _spawnMin && { _d <= _spawnMax }) exitWith { _okDist = true };
                } forEach _players;
                if (_okDist && { [_p, ""] call _minDistToStates >= _minSpacing }) then {
                    _picked = _p;
                };
            };
        };
        if (count _picked >= 2) exitWith {};
    } forEach _candidates;
    _picked
};

private _tryPickAggressive = {
    params ["_candidates", "_players", "_base"];
    private _picked = [];
    {
        private _p = _x;
        if (count _p < 2) then { };
        if ((_p distance2D _base) < _aggMinFromBase) then { };
        private _okDist = false;
        {
            private _d = _p distance2D (getPosATL _x);
            if (_d >= _aggMin && { _d <= _aggMax }) exitWith { _okDist = true };
        } forEach _players;
        if (_okDist && { [_p, ""] call _minDistToStates >= _minSpacing }) then {
            _picked = _p;
        };
        if (count _picked >= 2) exitWith {};
    } forEach _candidates;
    _picked
};

// Up to one new roadblock per call: first qualifying active civ zone (main road midpoint in town). No "ahead of player" filter — that belonged to corridor logic and blocked in-zone spawns.
// Per-zone roll: FADE_dynamicRoadblockCivZoneSpawnChance (default 50%), or FADE_dynamicRoadblockCivZoneSpawnChanceEe when EE (FADE_dynRb_escapeZone set).
private _tryCivZoneSpawn = {
    params ["_players", "_base", "_zoneRadius"];
    if (!_civZoneMode) exitWith { false };
    if (isNil "FADE_civZoneState") exitWith { false };
    private _ids = keys FADE_civZoneState;
    if (_ids isEqualTo []) exitWith { false };
    private _eeRb = missionNamespace getVariable ["FADE_dynRb_escapeZone", []];
    private _isEeCiv = (_eeRb isEqualType []) && { count _eeRb >= 2 };
    private _civRollChance = if (_isEeCiv) then { _civZoneChanceEe } else { _civZoneChance };
    _ids = _ids call BIS_fnc_arrayShuffle;
    private _spawned = false;
    {
        if (_spawned) exitWith {};
        private _zid = _x;
        if ([_zid] call _zoneHasRoadblock) then { } else {
            if (random 1 > _civRollChance) then { } else {
            private _zt = missionNamespace getVariable [_zid, objNull];
            if (isNull _zt) then { } else {
                private _zc = getPosATL _zt;
                if (count _zc < 3) then { _zc = [(_zc select 0), (_zc select 1), 0] };
                private _nearZone = false;
                {
                    if ((getPosATL _x) distance2D _zc <= _civZonePlayerMax) exitWith { _nearZone = true };
                } forEach _players;
                if (!_nearZone) then { } else {
                    private _seg = [_zc, _zoneRadius] call _longestRoadMidInRadius;
                    if (count _seg < 2) then { } else {
                        _seg params ["_mid", "_rdir"];
                        if ((_mid distance2D _base) < _minBase) then { } else {
                            private _pdOk = false;
                            {
                                private _d = _mid distance2D (getPosATL _x);
                                if (_d >= _civZoneSpawnMin && { _d <= _civZoneSpawnMax }) exitWith { _pdOk = true };
                            } forEach _players;
                            if (_pdOk && { [_mid, ""] call _minDistToStates >= _minSpacing }) then {
                                [_mid, _rdir, _zid] call _spawnAt;
                                _spawned = true;
                            };
                        };
                    };
                };
            };
            };
        };
    } forEach _ids;
    _spawned
};

while { true } do {
    private _state = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
    private _enabled = missionNamespace getVariable ["FADE_dynamicRoadblocksEnabled", false];
    private _patrols = missionNamespace getVariable ["FADE_scenarioPatrols", false];

    if (!_enabled || { !_patrols }) then {
        if (count keys _state > 0) then {
            [] call FADE_dynamicRoadblocks_despawnAll;
            ["Patrols or dynamic roadblocks OFF — cleared all."] call _rbLog;
        };
    } else {
        private _zoneGoneRetainPlM = missionNamespace getVariable ["FADE_dynamicRoadblockZoneGoneRetainPlayerM", 1000];
        private _base = [missionNamespace getVariable ["FADE_basePos", [0, 0, 0]]] call _norm2;
        private _players = call _eligiblePlayers;

        {
            private _id = _x;
            private _e = _state get _id;
            if (count _e >= 2) then {
                _e params ["_cPos", "_bundle", ["_zId", ""]];
                private _goneZone = false;
                if (_zId != "" && { !isNil "FADE_civZoneState" }) then {
                    if (isNil { FADE_civZoneState get _zId }) then { _goneZone = true };
                };
                if (_goneZone) then {
                    private _keepForPlayers = false;
                    if (_zoneGoneRetainPlM > 0) then {
                        {
                            if (alive _x && { isPlayer _x } && { (getPosATL _x) distance2D _cPos <= _zoneGoneRetainPlM }) exitWith { _keepForPlayers = true };
                        } forEach allPlayers;
                    };
                    if (_keepForPlayers) then { } else {
                        [_bundle] call FADE_roadblock_despawnBundle;
                        _state deleteAt _id;
                        private _gzMsg = if (_zoneGoneRetainPlM > 0) then {
                            format ["Despawned %1 (civ zone inactive; no player within %2m).", _id, _zoneGoneRetainPlM]
                        } else {
                            format ["Despawned %1 (civ zone inactive).", _id]
                        };
                        [_gzMsg] call _rbLog;
                    };
                } else {
                    private _nearF = false;
                    {
                        if (!alive _x || { !isPlayer _x }) then { } else {
                            if (side group _x == (missionNamespace getVariable ["FADE_sideFriendly", west])) then {
                                if ((getPosATL _x) distance2D _cPos <= _despawnDist) then { _nearF = true };
                            };
                        };
                    } forEach allPlayers;
                    if (!_nearF) then {
                        [_bundle] call FADE_roadblock_despawnBundle;
                        _state deleteAt _id;
                        [format ["Despawned %1 (no friendly within %2m).", _id, _despawnDist]] call _rbLog;
                    };
                };
            };
        } forEach +(keys _state);

        if (count _players > 0 && { (count keys _state) < _maxActive }) then {
            private _structuredB = call _structuredCorridorEnd;
            private _hasStructured = (_structuredB isEqualType []) && { count _structuredB >= 2 };
            private _eeOn = missionNamespace getVariable ["FADE_dynRb_escapeZone", []];
            private _isEe = (_eeOn isEqualType []) && { count _eeOn >= 2 };
            private _activeCiv = !isNil "FADE_civZoneState" && { FADE_civZoneState isEqualType createHashMap } && { count (keys FADE_civZoneState) > 0 };
            private _skipCorAgg = _civZoneMode && { _civZoneOnly } && { _activeCiv } && { !_isEe };
            private _anchorAhead = if (_hasStructured) then {
                if (_isEe) then { +_base } else { +_structuredB }
            } else {
                []
            };
            private _zoneRad = missionNamespace getVariable ["FADE_civSpawnRadius", 1000];

            private _civI = 0;
            while { _civI < 12 && { (count keys (missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap])) < _maxActive } } do {
                _civI = _civI + 1;
                private _nCivBefore = count keys (missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap]);
                [
                    _players,
                    _base,
                    _zoneRad
                ] call _tryCivZoneSpawn;
                private _nCivAfter = count keys (missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap]);
                if (_nCivAfter <= _nCivBefore) exitWith {};
            };

            private _state = missionNamespace getVariable ["FADE_dynamicRoadblockState", createHashMap];
            if ((count keys _state) < _maxActive && { !_skipCorAgg }) then {
                if (_hasStructured) then {
                    private _corridorA = if (_isEe) then { +_structuredB } else { +_base };
                    private _corridorB = if (_isEe) then { +_base } else { +_structuredB };
                    private _tLo = if (_isEe) then { _eeTMin } else { _tDefaultMin };
                    private _tHi = if (_isEe) then { _eeTMax } else { _tDefaultMax };
                    private _corridorList = [_corridorA, _corridorB, _corridorSamples, _tLo, _tHi] call _roadsAlongCorridor;

                    private _rayList = [];
                    private _plShuf = +_players;
                    _plShuf = _plShuf call BIS_fnc_arrayShuffle;
                    private _nRay = (count _plShuf) min _rayMaxPl;
                    private _ri = 0;
                    while { _ri < _nRay } do {
                        private _pl = _plShuf select _ri;
                        private _from = getPosATL _pl;
                        if (count _from >= 2) then {
                            private _rays = [_from, _anchorAhead, _raySamples] call _roadsPlayerToAnchor;
                            { _rayList pushBack _x } forEach _rays;
                        };
                        _ri = _ri + 1;
                    };

                    private _merged = _corridorList + _rayList;
                    private _candidates = [_merged, 140] call _dedupePositions;
                    _candidates = _candidates call BIS_fnc_arrayShuffle;

                    if (random 1 < _spawnChance) then {
                        private _picked = [_candidates, _players, _anchorAhead, true, _base] call _tryPickSpawn;
                        if (count _picked >= 2) then {
                            [_picked, -1, ""] call _spawnAt;
                        };
                    };
                } else {
                    if (random 1 < _aggChance) then {
                        private _rawAgg = [_players, _base] call _aggressiveRoadCandidates;
                        private _candidates = [_rawAgg, 100] call _dedupePositions;
                        _candidates = _candidates call BIS_fnc_arrayShuffle;
                        private _picked = [_candidates, _players, _base] call _tryPickAggressive;
                        if (count _picked >= 2) then {
                            [_picked, -1, ""] call _spawnAt;
                        };
                    };
                };
            };
        };
    };

    sleep _poll;
};
