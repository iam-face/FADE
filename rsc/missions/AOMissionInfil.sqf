// AOMissionInfil.sqf - AO infiltration civ-zone resolution
if (!isServer) exitWith {};
FADE_ao_resolveInfilCivZones = {
    params [
        "_aoCenter",
        "_attackDir",
        "_bluInfilRef",
        "_opforInfilRef",
        ["_dryFn", {}],
        ["_findLandPosFn", {}],
        ["_zoneHalfDepth", 1000],
        ["_zoneHalfWidth", 1000],
        ["_maxCivDist", 3000]
    ];

    private _aoN = [_aoCenter] call FADE_normPos3;
    private _civEntries = [];
    {
        private _trig = missionNamespace getVariable [_x, objNull];
        if (!isNull _trig) then {
            private _p = getPosATL _trig;
            if (_p isEqualType [] && { count _p >= 2 }) then {
                _civEntries pushBack [_x, [(_p select 0), (_p select 1), (_p param [2, 0])]];
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);

    private _cosA = cos _attackDir;
    private _sinA = sin _attackDir;
    private _fnc_localAxes = {
        params ["_pos"];
        private _p = [_pos] call FADE_normPos3;
        private _dx = (_p select 0) - (_aoN select 0);
        private _dy = (_p select 1) - (_aoN select 1);
        [_dx * _cosA + _dy * _sinA, -_dx * _sinA + _dy * _cosA]
    };
    private _fnc_isInsideAo = {
        params ["_pos"];
        private _axes = [_pos] call _fnc_localAxes;
        (abs (_axes select 0) <= _zoneHalfDepth) && { abs (_axes select 1) <= _zoneHalfWidth }
    };
    private _fnc_depthScalar = {
        params ["_pos"];
        ([_pos] call _fnc_localAxes) select 0
    };

    // Eligible civ zones: outside AO rectangle, within _maxCivDist of AO centre
    private _eligibleCiv = _civEntries select {
        _x params ["_id", "_pos"];
        !([_pos] call _fnc_isInsideAo) && { (([_pos] call FADE_normPos3) distance2D _aoN) <= _maxCivDist }
    };

    private _fnc_rankedNear = {
        params ["_ref", "_wantBluforSide", "_excludeIds", "_pool"];
        private _refN = [_ref] call FADE_normPos3;
        private _ranked = [];
        {
            _x params ["_id", "_pos"];
            if (_id in _excludeIds) then { continue };
            private _depth = [_pos] call _fnc_depthScalar;
            private _onSide = if (_wantBluforSide) then { _depth > 0 } else { _depth < 0 };
            if (!_onSide) then { continue };
            _ranked pushBack [_refN distance2D ([_pos] call FADE_normPos3), _id, _pos];
        } forEach _pool;
        [_ranked, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy
    };

    private _fnc_pickZone = {
        params ["_ref", "_wantBluforSide", "_excludeIds", "_pool"];
        private _ranked = [_ref, _wantBluforSide, _excludeIds, _pool] call _fnc_rankedNear;
        if (_ranked isEqualTo []) exitWith { ["", []] };
        private _best = _ranked select 0;
        [_best select 1, _best select 2]
    };

    private _fnc_landAt = {
        params ["_anchor", "_fallback"];
        private _fb = if (_fallback isEqualType [] && { count _fallback >= 2 }) then { +_fallback } else { +_anchor };
        private _out = [_anchor, 50, 500] call _findLandPosFn;
        if (!(_out isEqualType []) || { count _out < 2 } || { !([_out] call _dryFn) }) then {
            _out = [_anchor, 100, 800] call _findLandPosFn;
        };
        if (!(_out isEqualType []) || { count _out < 2 } || { !([_out] call _dryFn) }) then { _out = +_fb };
        if (count _out < 3) then { _out set [2, 0] };
        _out
    };

    private _fnc_ensureOutsideAo = {
        params ["_pos", "_edgeRef"];
        if (_pos isEqualType [] && { count _pos >= 2 } && { !([_pos] call _fnc_isInsideAo) }) exitWith { _pos };
        [_edgeRef, _edgeRef] call _fnc_landAt
    };

    private _bluPick = [_bluInfilRef, true, [], _eligibleCiv] call _fnc_pickZone;
    _bluPick params ["_bluId", "_bluZonePos"];
    private _opforPick = [_opforInfilRef, false, if (_bluId == "") then { [] } else { [_bluId] }, _eligibleCiv] call _fnc_pickZone;
    _opforPick params ["_opforId", "_opforZonePos"];

    if (_bluId == "") then {
        private _pool = _eligibleCiv select { ([_x select 1] call _fnc_depthScalar) > 0 };
        if (_opforId != "") then {
            _pool = _pool select { !((_x select 0) isEqualTo _opforId) };
            private _opDepth = [_opforZonePos] call _fnc_depthScalar;
            private _oppPool = _pool select {
                private _d = [_x select 1] call _fnc_depthScalar;
                if (_opDepth < 0) then { _d > 0 } else { _d < 0 }
            };
            if (count _oppPool > 0) then { _pool = _oppPool };
        };
        _pool = [_pool, [], { [_bluInfilRef] call FADE_normPos3 distance2D ([_x select 1] call FADE_normPos3) }, "ASCEND"] call BIS_fnc_sortBy;
        if (count _pool > 0) then {
            _bluId = (_pool select 0) select 0;
            _bluZonePos = (_pool select 0) select 1;
        };
    };

    if (_opforId == "" || { _opforId isEqualTo _bluId }) then {
        private _excl = if (_bluId == "") then { [] } else { [_bluId] };
        private _rankedOp = [_opforInfilRef, false, _excl, _eligibleCiv] call _fnc_rankedNear;
        if (_rankedOp isEqualTo []) then {
            private _pool = _eligibleCiv select { !((_x select 0) in _excl) && { ([_x select 1] call _fnc_depthScalar) < 0 } };
            if (_bluId != "" && { count _pool > 1 }) then {
                private _bluDepth = [_bluZonePos] call _fnc_depthScalar;
                private _oppPool = _pool select {
                    private _d = [_x select 1] call _fnc_depthScalar;
                    if (_bluDepth >= 0) then { _d < 0 } else { _d > 0 }
                };
                if (count _oppPool > 0) then { _pool = _oppPool };
            };
            _pool = [_pool, [], { [_opforInfilRef] call FADE_normPos3 distance2D ([_x select 1] call FADE_normPos3) }, "ASCEND"] call BIS_fnc_sortBy;
            if (count _pool > 0) then {
                _opforId = (_pool select 0) select 0;
                _opforZonePos = (_pool select 0) select 1;
            };
        } else {
            private _o = _rankedOp select 0;
            _opforId = _o select 1;
            _opforZonePos = _o select 2;
        };
    };

    // No eligible civ zone: fall back to precomputed AO edge references (outside the rectangle).
    private _bluAnchor = if (_bluZonePos isEqualType [] && { count _bluZonePos >= 2 }) then { _bluZonePos } else { +_bluInfilRef };
    private _opforAnchor = if (_opforZonePos isEqualType [] && { count _opforZonePos >= 2 }) then { _opforZonePos } else { +_opforInfilRef };
    private _bluPos = [_bluAnchor, _bluInfilRef] call _fnc_landAt;
    private _opforPos = [_opforAnchor, _opforInfilRef] call _fnc_landAt;
    _bluPos = [_bluPos, _bluInfilRef] call _fnc_ensureOutsideAo;
    _opforPos = [_opforPos, _opforInfilRef] call _fnc_ensureOutsideAo;

    [[_bluId, _bluPos], [_opforId, _opforPos]]
};
