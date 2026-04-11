// =============================================================================
// Pad vehicle service - full repair, refuel, rearm at all spawn pads (server)
// Applies to helipads (FADE_helipadList) and land vehicle points (FADE_vehiclePoints).
// Aircraft must be on the ground; all types must be nearly stationary.
// =============================================================================
if (!isServer) exitWith {};

waitUntil { !isNil "FADE_helipadList" && !isNil "FADE_vehiclePoints" };

[] spawn {
    scriptName "FADE_padVehicleService";
    while { true } do {
        private _interval = missionNamespace getVariable ["FADE_padServiceInterval", 7];
        sleep _interval;
        private _radius = missionNamespace getVariable ["FADE_padServiceRadius", 22];
        private _maxSpeedKmh = missionNamespace getVariable ["FADE_padServiceMaxSpeedKmh", 8];
        private _helipadList = missionNamespace getVariable ["FADE_helipadList", []];
        private _vehPoints = missionNamespace getVariable ["FADE_vehiclePoints", []];
        private _rawPos = [];
        { _rawPos pushBack (getPosATL (_x select 0)) } forEach _helipadList;
        { _rawPos pushBack (getPosATL _x) } forEach _vehPoints;
        private _dedupe = missionNamespace getVariable ["FADE_padServiceDedupeDist", 12];
        private _padPositions = if (_dedupe <= 0) then {
            +_rawPos
        } else {
            private _uniq = [];
            {
                private _p = _x;
                if ((_uniq findIf { _x distance2D _p < _dedupe }) < 0) then { _uniq pushBack _p };
            } forEach _rawPos;
            _uniq
        };
        if (_padPositions isEqualTo []) then { continue };
        private _candidates = [];
        {
            private _pos = _x;
            private _near = nearestObjects [_pos, ["AllVehicles"], _radius];
            { _candidates pushBackUnique _x } forEach _near;
        } forEach _padPositions;
        {
            private _veh = _x;
            if (
                isNull _veh || { !alive _veh }
                || { _veh isKindOf "Man" }
                || { _veh isKindOf "StaticWeapon" }
                || { _veh isKindOf "ParachuteBase" }
                || { (_veh isKindOf "Air") && { !isTouchingGround _veh } }
                || { speed _veh > _maxSpeedKmh }
            ) then { } else {
                _veh setFuel 1;
                _veh setDamage 0;
                _veh setVehicleAmmo 1;
            };
        } forEach _candidates;
    };
};
