// =============================================================================
// FADE_MedevacMissionCommon.sqf  -  CASEVAC / CSAR / field-pickup shared setup
// =============================================================================
if (!isServer) exitWith {};

// BIS_fnc_findSafePos returns ASL; setPosATL needs ATL (Z above local terrain). Use Z=0 on dry land.
FADE_mission_groundAtlPos = {
    params ["_pos"];
    private _p = [_pos] call FADE_normPos3;
    if (!([_p] call FADE_surfaceIsDry)) then {
        private _dryFn = missionNamespace getVariable ["FADE_ensureDryLandPos", {}];
        if (!(_dryFn isEqualTo {})) then { _p = [_p, _p] call _dryFn };
        _p = [_p] call FADE_normPos3;
    };
    [_p select 0, _p select 1, 0]
};

FADE_mission_findPickupSpawnPos = {
    params ["_destPos", ["_offset", 10], ["_searchRadius", 15]];
    private _wpPos = _destPos getPos [_offset, random 360];
    _wpPos = [[_wpPos, 0, _searchRadius, 2, 1, 0.3, 0, [], _wpPos], _wpPos] call FADE_findSafePosArray;
    if (count _wpPos < 2) then { _wpPos = _destPos getPos [_offset, random 360] };
    [_wpPos] call FADE_mission_groundAtlPos
};

// Crashed friendly aircraft / wreck prop for CASEVAC and CSAR scene dressing.
FADE_mission_spawnCasualtyHeliWreck = {
    params ["_site", ["_taskId", ""]];
    private _wpPos = [_site, 10, 15] call FADE_mission_findPickupSpawnPos;
    private _friendlyVehicleClasses = missionNamespace getVariable ["FADE_friendlyVehicleClasses", []];
    private _factionHelis = _friendlyVehicleClasses select {
        _x isKindOf "Helicopter" && { getNumber (configFile >> "CfgVehicles" >> _x >> "isUav") < 1 }
    };
    private _wreckClasses = [
        "vn_air_f4b_wreck",
        "vn_air_oh6a_01_wreck",
        "Land_UH1H_Wreck_F",
        "BlackhawkWreck",
        "C130J_wreck_EP1"
    ];
    private _wreckOk = _wreckClasses select { isClass (configFile >> "CfgVehicles" >> _x) };
    if (count _wreckOk == 0) then {
        _wreckOk = ["Land_Wreck_Heli_Attack_01_F", "Land_Wreck_Heli_Attack_02_F"] select { isClass (configFile >> "CfgVehicles" >> _x) };
    };
    if (count _wreckOk == 0) then { _wreckOk = ["Land_Wreck_Heli_Attack_01_F"] };
    private _wreck = objNull;
    private _usedFactionHeli = false;
    private _aircraftClass = "";
    if (count _factionHelis > 0) then {
        _aircraftClass = selectRandom _factionHelis;
        _wreck = createVehicle [_aircraftClass, _wpPos, [], 0, "NONE"];
        if (!isNull _wreck) then {
            _wreck setPosATL _wpPos;
            _wreck setDir (random 360);
            _wreck setVelocity [0, 0, 0];
            _wreck engineOn false;
            private _sn = surfaceNormal _wpPos;
            if ((vectorMagnitude _sn) > 0.5) then { _wreck setVectorUp _sn };
            _usedFactionHeli = true;
        };
    };
    if (isNull _wreck) then {
        _aircraftClass = selectRandom _wreckOk;
        _wreck = createVehicle [_aircraftClass, _wpPos, [], 0, "NONE"];
        if (!isNull _wreck) then {
            _wreck setPosATL _wpPos;
            _wreck setDir (random 360);
            _usedFactionHeli = false;
        };
    };
    if (_usedFactionHeli && { !isNull _wreck }) then { _wreck setDamage 1 };
    if (_taskId != "" && { !isNull _wreck }) then {
        missionNamespace setVariable ["FADE_csarWreck_" + _taskId, _wreck];
        [_taskId, _wreck] call FADE_missionEnt_registerObject;
    };
    [_wreck, _aircraftClass, _wpPos, _usedFactionHeli]
};

FADE_mission_spawnFriendlyPickupGroup = {
    params ["_destPos", "_sideFriendly", "_unitClasses", ["_explicitPos", []]];
    private _wpPos = if (count _explicitPos >= 2) then {
        [_explicitPos] call FADE_mission_groundAtlPos
    } else {
        [_destPos] call FADE_mission_findPickupSpawnPos
    };
    private _group = [_wpPos, _sideFriendly, _unitClasses] call FADE_spawnFriendlyInfantryGroupAt;
    if (isNull _group) exitWith { [grpNull, _wpPos] };
    {
        if (!isNull _x) then {
            _x setPosATL _wpPos;
            _x setVectorUp surfaceNormal _wpPos;
        };
    } forEach units _group;
    [_group] call (missionNamespace getVariable ["FADE_assignGroupCallsign", {}]);
    [_group] call FADE_attachNightStrobes;
    _group addWaypoint [_wpPos, 0];
    [_group, _wpPos]
};

FADE_mission_applyPickupGroupPosture = {
    params ["_group", "_inContact"];
    if (_inContact) then {
        _group setBehaviour "COMBAT";
        _group setFormation "DIAMOND";
    } else {
        _group setBehaviour "SAFE";
        _group setCombatMode "GREEN";
        _group setFormation "STAG COLUMN";
    };
};

// CASEVAC: KIA some squad members and wound survivors (ACE when available).
FADE_mission_casevacCasualtyPrep = {
    params ["_group"];
    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    private _nStart = count units _group;
    if (_nStart < 2) exitWith {};
    private _kia = (1 + floor random 2) min (_nStart - 1);
    for "_k" from 1 to _kia do {
        private _u = selectRandom units _group;
        if (!isNull _u) then { deleteVehicle _u };
    };
    {
        if (!alive _x) then {} else {
            if (_useACE && _aceHasAddDamage) then {
                private _p = selectRandom ["Head", "Body", "LeftArm", "RightArm", "LeftLeg", "RightLeg"];
                [_x, 0.12 + random 0.22, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
                if (_aceHasAddWound) then {
                    [_x, toLower _p, ["Laceration", 1, 0, 0.2]] call ace_medical_fnc_addWound;
                };
            } else {
                _x setDamage ((damage _x) + 0.15 + random 0.25);
            };
        };
    } forEach units _group;
};

// CSAR: wound survivor(s), keep invulnerable until pickup window opens.
FADE_mission_csarPilotWoundPrep = {
    params ["_group"];
    private _useACE = isClass (configFile >> "CfgPatches" >> "ace_medical");
    private _aceHasAddDamage = !isNil "ace_medical_fnc_addDamageToUnit";
    private _aceHasAddWound = !isNil "ace_medical_fnc_addWound";
    {
        if (_useACE && _aceHasAddDamage) then {
            _x allowDamage true;
            private _p = selectRandom ["Body", "LeftLeg", "RightLeg"];
            [_x, 0.18 + random 0.2, _p, "bullet", objNull] call ace_medical_fnc_addDamageToUnit;
            if (_aceHasAddWound) then { [_x, toLower _p, ["VelocityWound", 1, 1, 0.4]] call ace_medical_fnc_addWound };
            _x allowDamage false;
        } else {
            _x allowDamage true;
            _x setDamage (0.25 + random 0.2);
            _x allowDamage false;
        };
    } forEach units _group;
    [_group] spawn {
        params ["_grp"];
        sleep 30;
        if (isNull _grp) exitWith {};
        { if (!isNull _x && { alive _x }) then { _x allowDamage true } } forEach units _grp;
    };
};

missionNamespace setVariable ["FADE_mission_groundAtlPos", FADE_mission_groundAtlPos];
missionNamespace setVariable ["FADE_mission_findPickupSpawnPos", FADE_mission_findPickupSpawnPos];
missionNamespace setVariable ["FADE_mission_spawnCasualtyHeliWreck", FADE_mission_spawnCasualtyHeliWreck];
missionNamespace setVariable ["FADE_mission_spawnFriendlyPickupGroup", FADE_mission_spawnFriendlyPickupGroup];
missionNamespace setVariable ["FADE_mission_applyPickupGroupPosture", FADE_mission_applyPickupGroupPosture];
missionNamespace setVariable ["FADE_mission_casevacCasualtyPrep", FADE_mission_casevacCasualtyPrep];
missionNamespace setVariable ["FADE_mission_csarPilotWoundPrep", FADE_mission_csarPilotWoundPrep];
