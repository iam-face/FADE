// =============================================================================
// ServerGameplayCore.sqf � extracted from ServerGameplay (compile via ServerGameplay.sqf)
// =============================================================================

publicVariable "FADE_heliClasses";
publicVariable "FADE_landVehicleClasses";
publicVariable "FADE_aircraftSpawnWhitelist";
publicVariable "FADE_planeForbiddenPads";
publicVariable "FADE_friendlyUnits";
publicVariable "FADE_enemyUnits";
publicVariable "FADE_friendlyVehicleClasses";
publicVariable "FADE_vehiclePoints";
publicVariable "FADE_helipads";
publicVariable "FADE_boards";
publicVariable "FADE_vehicleBoard";
publicVariable "FADE_vehicleTerminal";
publicVariable "FADE_firesTerminal";
publicVariable "FADE_sniperTerminal";
publicVariable "FADE_terminalRange";
publicVariable "FADE_medicalTrainingTerminal";
publicVariable "FADE_missionBoard";
publicVariable "FADE_cqbBoard";
publicVariable "FADE_cqbDrillActive";
publicVariable "FADE_cqbStartDrill";
publicVariable "FADE_cqbEndDrill";
publicVariable "FADE_cqbLastResult";

FADE_lazyLoadRangeServers = {
    if (!isServer) exitWith {};
    if (missionNamespace getVariable ["FADE_rangeServersLoaded", false]) exitWith {};
    call compile preprocessFileLineNumbers "rsc\SniperRangeServer.sqf";
    call compile preprocessFileLineNumbers "rsc\RangeShared.sqf";
    call compile preprocessFileLineNumbers "rsc\RangeServer.sqf";
    missionNamespace setVariable ["FADE_rangeServersLoaded", true];
};
missionNamespace setVariable ["FADE_lazyLoadRangeServers", FADE_lazyLoadRangeServers];

FADE_rangeStartSession = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_rangeStartSession_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_rangeStartSession";

FADE_rangeEndSession = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_rangeEndSession_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_rangeEndSession";

FADE_rangeRequestAtWeaponState = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_rangeRequestAtWeaponState_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_rangeRequestAtWeaponState";

FADE_rangeSpawnFriendlyLandAtSlot = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_rangeSpawnFriendlyLandAtSlot_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_rangeSpawnFriendlyLandAtSlot";

FADE_rangeDespawnFriendlyLandAtSlot = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_rangeDespawnFriendlyLandAtSlot_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_rangeDespawnFriendlyLandAtSlot";

FADE_sniperStartSession = {
    [] call FADE_lazyLoadRangeServers;
    private _impl = missionNamespace getVariable ["FADE_sniperStartSession_impl", {}];
    if (_impl isEqualType {}) then { _this call _impl };
};
publicVariable "FADE_sniperStartSession";

addMissionEventHandler ["HandleDisconnect", {
    params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];
    if (missionNamespace getVariable ["FADE_cqbDrillActive", false]) then {
        private _suid = missionNamespace getVariable ["FADE_cqbStarterUid", ""];
        if (_suid != "" && { _uid == _suid }) then {
            [objNull, "CQB drill ended: trainee disconnected.", true] call FADE_cqbEndDrill;
        };
    };
    if (missionNamespace getVariable ["FADE_sniperRangeActive", false]) then {
        private _suid = missionNamespace getVariable ["FADE_sniperStarterUid", ""];
        if (_suid != "" && { _uid == _suid }) then {
            [objNull, "Sniper range ended: shooter disconnected.", true] call FADE_sniperEndSession;
        };
    };
    if (missionNamespace getVariable ["FADE_rangeSessionActive", false]) then {
        private _suid = missionNamespace getVariable ["FADE_rangeStarterUid", ""];
        if (_suid != "" && { _uid == _suid }) then {
            [objNull, "Range session ended: shooter disconnected."] call FADE_rangeEndSession;
        };
    };
    private _ou = missionNamespace getVariable ["FAC_firesFoS_droneOwnerUid", ""];
    if (_uid == _ou && { _ou != "" }) then {
        private _fn = missionNamespace getVariable ["FADE_firesFoS_droneDespawnServer", {}];
        if (_fn isEqualType {}) then { [] call _fn };
    };
}];

publicVariable "FADE_loadoutBoxes";
publicVariable "FADE_loadoutBox";
publicVariable "FADE_loadoutBox2";
publicVariable "FADE_workbench";
publicVariable "FADE_basePos";
publicVariable "FADE_bSpPoints";
publicVariable "FADE_mapMin";
publicVariable "FADE_mapMax";
publicVariable "FADE_mapMinX";
publicVariable "FADE_mapMaxX";
publicVariable "FADE_mapMinY";
publicVariable "FADE_mapMaxY";

// -----------------------------------------------------------------------------
// Update helipad markers and padIndicator_* signs (aircraft only, not ground vehicles).
// FADE_padMarkerOriginalText is populated above; do not reset it here.
// -----------------------------------------------------------------------------
FADE_buildPadIndicatorTexture = {
    params ["_slotNum", ["_vehicleDisplayName", ""]];
    private _slotLine = format ["AIRCRAFT SLOT %1", _slotNum];
    private _statusLine = if (_vehicleDisplayName == "") then { "Empty" } else { _vehicleDisplayName };
    private _text = format ["\n\n\n%1\n\n%2", _slotLine, _statusLine];
    format ["#(rgb,512,512,1)text(0,1,""TahomaB"",0.075,""#000000"",""#FFFFFF"",""%1"")", _text]
};

FADE_updatePadIndicators = {
    if (count FADE_padIndicators == 0) exitWith {};
    {
        if (isNull _x) then { continue };
        private _padIdx = _forEachIndex;
        if (_padIdx >= count FADE_helipadList) then { continue };
        (FADE_helipadList select _padIdx) params ["_padObj"];
        private _pos = getPosATL _padObj;
        private _near = nearestObjects [_pos, ["Air"], 10];
        private _veh = (_near select { !isNull _x && { alive _x } }) param [0, objNull];
        private _vehName = "";
        if (!isNull _veh) then {
            _vehName = getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName");
            if (_vehName == "") then { _vehName = typeOf _veh };
        };
        private _tex = [_padIdx + 1, _vehName] call FADE_buildPadIndicatorTexture;
        _x setObjectTextureGlobal [0, _tex];
    } forEach FADE_padIndicators;
};

FADE_updateHelipadMarkers = {
    private _markers = missionNamespace getVariable ["FADE_helipadMarkers", []];
    if (count _markers > 0) then {
        {
            private _padIdx = _forEachIndex;
            private _mrkName = if (_padIdx < count _markers) then { _markers select _padIdx } else { "" };
            if (_mrkName == "" || { getMarkerColor _mrkName == "" }) then { continue };
            _x params ["_padObj", "_padName"];
            private _pos = getPosATL _padObj;
            private _near = nearestObjects [_pos, ["Air"], 10];
            private _veh = (_near select { !isNull _x && { alive _x } }) param [0, objNull];
            if (!isNull _veh) then {
                private _displayName = getText (configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName");
                if (_displayName == "") then { _displayName = typeOf _veh };
                _mrkName setMarkerText _displayName;
            } else {
                private _orig = FADE_padMarkerOriginalText param [_padIdx, ""];
                if (_orig == "") then { _orig = format ["Pad %1", _padIdx + 1] };
                _mrkName setMarkerText _orig;
            };
        } forEach FADE_helipadList;
    };
    call FADE_updatePadIndicators;
};

// Periodic pad marker / indicator update - detects when aircraft leave pads (e.g. take off)
[] spawn {
    while { true } do {
        private _iv = missionNamespace getVariable ["FADE_helipadMarkerUpdateInterval", 8];
        if (_iv < 2) then { _iv = 2 };
        sleep _iv;
        if (count (missionNamespace getVariable ["FADE_helipadMarkers", []]) > 0 || { count FADE_padIndicators > 0 }) then {
            call FADE_updateHelipadMarkers;
        };
    };
};
call FADE_updateHelipadMarkers;