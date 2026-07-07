// =============================================================================
// FAC_DebugCivTownMarkers.sqf  -  map markers for all civ town zones (active vs idle)
// Server poll; enabled when FADE_civTownDebugMarkers is true (lobby param).
// =============================================================================

if (!isServer) exitWith {};

FADE_civ_townDebugMarkerId = {
    params ["_zoneId"];
    "FADE_civTown_" + _zoneId
};

FADE_civ_syncTownDebugMarker = {
    params ["_zoneId", ["_active", false]];
    if !(missionNamespace getVariable ["FADE_civTownDebugMarkers", false]) exitWith {};
    private _trig = missionNamespace getVariable [_zoneId, objNull];
    if (isNull _trig) exitWith {};
    private _pos = getPosATL _trig;
    private _mrkId = [_zoneId] call FADE_civ_townDebugMarkerId;
    private _locName = _zoneId;
    if (!isNil "FADE_civZoneMeta" && { FADE_civZoneMeta isEqualType createHashMap }) then {
        private _meta = FADE_civZoneMeta get _zoneId;
        if (!isNil "_meta") then {
            _locName = _meta getOrDefault ["locName", _zoneId];
        };
    };
    private _label = format ["%1 (%2)", _locName, if (_active) then { "ACTIVE" } else { "idle" }];
    if (markerColor _mrkId == "") then {
        [_mrkId, _pos, ""] call FADE_createRegisteredMarker;
        _mrkId setMarkerType "hd_flag";
        _mrkId setMarkerSize [0.55, 0.55];
    } else {
        _mrkId setMarkerPos _pos;
    };
    _mrkId setMarkerText _label;
    _mrkId setMarkerColor (if (_active) then { "ColorCivilian" } else { "ColorGrey" });
    _mrkId setMarkerAlpha (if (_active) then { 0.9 } else { 0.55 });
};

FADE_civ_clearTownDebugMarkers = {
    {
        private _mrkId = [_x] call FADE_civ_townDebugMarkerId;
        if (markerColor _mrkId != "") then { deleteMarker _mrkId };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
};

[] spawn {
    waitUntil {
        sleep 2;
        !isNil "FADE_civTriggerNames" && { (missionNamespace getVariable ["FADE_civTriggerNames", []]) isNotEqualTo [] }
    };

    private _interval = 12;
    while { true } do {
        if (missionNamespace getVariable ["FADE_civTownDebugMarkers", false]) then {
            {
                private _zoneId = _x;
                private _active = !isNil "FADE_civZoneState" && { !(isNil { FADE_civZoneState get _zoneId }) };
                [_zoneId, _active] call FADE_civ_syncTownDebugMarker;
            } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
        } else {
            [] call FADE_civ_clearTownDebugMarkers;
        };
        sleep _interval;
    };
};
