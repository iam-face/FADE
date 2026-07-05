// =============================================================================
// FADE_ZoneCaptureHelpers.sqf — shared zone markers + capture/hold tick (Operation, Invasion)
// =============================================================================

// Ellipse border + hd_flag icon. Returns [_areaMarker, _iconMarker]; appends both to _markerNamesOut if provided.
FADE_zone_createCaptureMarkerPair = {
    params [
        "_taskId",
        "_markerPrefix",
        "_idx",
        "_center",
        "_zoneRadius",
        "_markerColor",
        "_markerText",
        "_mkrJitter",
        ["_markerNamesOut", []]
    ];
    private _centerN = [_center] call FADE_normPos3;
    private _mName = format ["%1_%2_%3", _markerPrefix, _taskId, _idx];
    [_taskId, _mName, _centerN, _zoneRadius, _markerColor, 0.5] call FADE_mission_createRadiusMarker;

    private _iconName = _mName + "_icon";
    private _mi = createMarker [_iconName, _centerN];
    [_taskId, _iconName] call FADE_missionEnt_registerMarker;
    _mi setMarkerType "hd_flag";
    _mi setMarkerColor _markerColor;
    _mi setMarkerText _markerText;

    if (_markerNamesOut isEqualType []) then {
        _markerNamesOut pushBack _mName;
        _markerNamesOut pushBack _iconName;
    };
    [_mName, _iconName]
};

// Operation capture tick. Returns updated captured flag for zone _i.
FADE_zone_tickOperationCapture = {
    params [
        "_center",
        "_zoneRadius",
        "_wasCaptured",
        "_bluforCnt",
        "_eCnt",
        "_mArea",
        "_mIcon",
        "_markerFriendly",
        "_markerEnemy",
        "_vgCancelEllipse",
        "_vgOwner"
    ];
    private _captured = _wasCaptured;
    if (_eCnt > 0) then {
        _captured = false;
        if (_bluforCnt > 0) then {
            if (_eCnt > _bluforCnt) then {
                [_mArea, _markerEnemy] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor _markerEnemy;
            } else {
                [_mArea, "ColorOrange"] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor "ColorOrange";
            };
        } else {
            [_mArea, _markerEnemy] call FADE_mission_setRadiusMarkerColor;
            _mIcon setMarkerColor _markerEnemy;
        };
    } else {
        if (_bluforCnt > 0) then {
            if (!_wasCaptured && { !(_vgCancelEllipse isEqualTo {}) }) then {
                [_center, _zoneRadius, _vgOwner] call _vgCancelEllipse;
            };
            _captured = true;
            [_mArea, _markerFriendly] call FADE_mission_setRadiusMarkerColor;
            _mIcon setMarkerColor _markerFriendly;
        } else {
            if (_wasCaptured) then {
                [_mArea, _markerFriendly] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor _markerFriendly;
            } else {
                _captured = false;
                [_mArea, _markerEnemy] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor _markerEnemy;
            };
        };
    };
    _captured
};

// Invasion hold tick. Returns updated held flag for zone _i.
FADE_zone_tickInvasionHold = {
    params [
        "_center",
        "_zoneRadius",
        "_wasHeld",
        "_bluforCnt",
        "_eCnt",
        "_mArea",
        "_mIcon",
        "_markerFriendly",
        "_markerEnemy",
        "_vgCancelEllipse",
        "_vgOwner"
    ];
    private _held = _wasHeld;
    if (_bluforCnt > 0 && { _eCnt > 0 }) then {
        [_mArea, "ColorOrange"] call FADE_mission_setRadiusMarkerColor;
        _mIcon setMarkerColor "ColorOrange";
    } else {
        if (_eCnt > 0) then {
            _held = false;
            [_mArea, _markerEnemy] call FADE_mission_setRadiusMarkerColor;
            _mIcon setMarkerColor _markerEnemy;
        } else {
            if (_bluforCnt > 0) then {
                if (!_wasHeld && { !(_vgCancelEllipse isEqualTo {}) }) then {
                    [_center, _zoneRadius, _vgOwner] call _vgCancelEllipse;
                };
                _held = true;
                [_mArea, _markerFriendly] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor _markerFriendly;
            } else {
                private _col = if (_wasHeld) then { _markerFriendly } else { _markerEnemy };
                [_mArea, _col] call FADE_mission_setRadiusMarkerColor;
                _mIcon setMarkerColor _col;
            };
        };
    };
    _held
};

missionNamespace setVariable ["FADE_zone_createCaptureMarkerPair", FADE_zone_createCaptureMarkerPair];
missionNamespace setVariable ["FADE_zone_tickOperationCapture", FADE_zone_tickOperationCapture];
missionNamespace setVariable ["FADE_zone_tickInvasionHold", FADE_zone_tickInvasionHold];
