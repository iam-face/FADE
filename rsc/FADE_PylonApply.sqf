// Pylon apply for the vehicle owner only.
// Rho 2026 RS_MH6V3_fnc_syncPylonOwner remoteExecCall's itself to target 0 when the
// caller is not the server. Target 0 includes the caller, so every client rebroadcasts
// and the server logs "RS_MH6V3: pylon N setPylonLoadOut failed" until the mission dies.
// The replacement below sends that sync to the aircraft only.
// ACE 3.21.2 ace_pylons_fnc_configurePylons fires setPylonLoadout through CBA_fnc_globalEvent,
// so every machine runs it. The engine then logs
// "Unable to set magazine '%s' on pylon %d, check hardpoint and mass on magazine and pylon."
// Off-owner calls and a pilot turret of [-1] (setPylonLoadout rejects [-1]; the pilot path is [])
// keep failing. A rejected magazine left on the vehicle is what filled the server RPT.
// This file replaces that Apply path. One attempt, then one forced attempt, then the slot is cleared.

FADE_pylon_normalizeTurret = {
    params [["_turret", []]];
    if (_turret isEqualTo [-1]) exitWith { [] };
    if !(_turret isEqualType []) exitWith { [] };
    _turret
};

FADE_pylon_magazineListed = {
    params ["_veh", "_pylonIndex", "_magazine"];
    if (_magazine == "") exitWith { true };
    private _allowed = _veh getCompatiblePylonMagazines _pylonIndex;
    if !(_allowed isEqualType []) exitWith { false };
    if (_allowed isEqualTo []) exitWith { false };
    if ((_allowed select 0) isEqualType []) then {
        _allowed = _allowed select 0;
    };
    _magazine in _allowed
};

// Local to _veh. _ammo < 0 leaves the round count alone.
FADE_pylon_applyLocal = {
    params ["_veh", "_pylonIndex", "_magazine", ["_turret", []], ["_ammo", -1]];
    if (!local _veh) exitWith { false };
    if (isNull _veh || {!alive _veh}) exitWith { false };
    if !(_pylonIndex isEqualType 0) exitWith { false };
    _pylonIndex = round _pylonIndex;
    if (_pylonIndex < 1) exitWith { false };
    if !(_magazine isEqualType "") then { _magazine = "" };
    _turret = [_turret] call FADE_pylon_normalizeTurret;

    private _info = getAllPylonsInfo _veh param [_pylonIndex - 1, []];
    if (_info isEqualTo []) exitWith { false };
    private _oldMag = _info param [3, ""];
    private _curTurret = [_info param [2, []]] call FADE_pylon_normalizeTurret;
    if (_oldMag isEqualTo _magazine && {_curTurret isEqualTo _turret}) exitWith {
        if (_ammo >= 0) then { _veh setAmmoOnPylon [_pylonIndex, round (_ammo max 0)] };
        true
    };

    private _ok = false;
    if (_magazine == "") then {
        _ok = _veh setPylonLoadout [_pylonIndex, "", true, _turret];
    } else {
        if ([_veh, _pylonIndex, _magazine] call FADE_pylon_magazineListed) then {
            _ok = _veh setPylonLoadout [_pylonIndex, _magazine, false, _turret];
            if (!_ok) then {
                _ok = _veh setPylonLoadout [_pylonIndex, _magazine, true, _turret];
            };
        };
        if (!_ok) then {
            private _cleared = _veh setPylonLoadout [_pylonIndex, "", true, _turret];
            if (!_cleared && {!(_curTurret isEqualTo _turret)}) then {
                _cleared = _veh setPylonLoadout [_pylonIndex, "", true, _curTurret];
            };
            diag_log format [
                "[FADE] Pylon %1 on %2 rejected %3; slot clear %4 (not retried).",
                _pylonIndex, typeOf _veh, _magazine, _cleared
            ];
        };
    };

    // Includes the slot just written, so a replacement that shares pylonWeapon is kept.
    if (_oldMag != "" && {_oldMag != _magazine || {!_ok}}) then {
        private _oldWeapon = getText (configFile >> "CfgMagazines" >> _oldMag >> "pylonWeapon");
        if (_oldWeapon != "") then {
            private _used = false;
            {
                private _mag = _x param [3, ""];
                if (_mag != "" && {getText (configFile >> "CfgMagazines" >> _mag >> "pylonWeapon") == _oldWeapon}) then {
                    _used = true;
                };
            } forEach (getAllPylonsInfo _veh);
            if (!_used) then {
                {
                    if (_veh turretLocal _x) then {
                        _veh removeWeaponTurret [_oldWeapon, _x];
                    };
                } forEach [[-1], [0]];
            };
        };
    };
    if (!_ok) exitWith { false };

    if (_ammo >= 0) then { _veh setAmmoOnPylon [_pylonIndex, round (_ammo max 0)] };
    true
};

// Owner runs the command. Empty aircraft are server-local; a manned aircraft is local to the driver.
FADE_pylon_apply = {
    params ["_veh", "_pylonIndex", "_magazine", ["_turret", []], ["_ammo", -1]];
    if (isNull _veh) exitWith { false };
    if (local _veh) exitWith {
        [_veh, _pylonIndex, _magazine, _turret, _ammo] call FADE_pylon_applyLocal
    };
    [_veh, _pylonIndex, _magazine, _turret, _ammo] remoteExec ["FADE_pylon_applyLocal", _veh];
    true
};

// One pass after create / setVehicleAmmo. getAllPylonsInfo reports the pilot as [-1]; that value is left alone.
// A magazine the pylon does not list is cleared once. An empty compatible list is left alone (config not ready).
FADE_pylon_sanitizeVehicle = {
    params ["_veh"];
    if (isNull _veh || {!local _veh}) exitWith {};
    private _infos = getAllPylonsInfo _veh;
    if (_infos isEqualTo []) exitWith {};
    {
        _x params ["_idx", "", "_turret", "_mag"];
        if (_mag == "") then { continue };
        private _allowed = _veh getCompatiblePylonMagazines _idx;
        if !(_allowed isEqualType []) then { continue };
        if (_allowed isEqualTo []) then { continue };
        if ((_allowed select 0) isEqualType []) then { _allowed = _allowed select 0 };
        if (_mag in _allowed) then { continue };
        private _turretNorm = [_turret] call FADE_pylon_normalizeTurret;
        [_veh, _idx, "", _turretNorm, -1] call FADE_pylon_applyLocal;
    } forEach _infos;
};

// ACE Apply and ZEN OK run on the client that opened the dialog. Redirect them before the first use.
if (hasInterface) then {
    if (!isNil "ace_pylons_fnc_configurePylons") then {
        ace_pylons_fnc_configurePylons = {
            params ["_pylonsToConfigure", ["_currentPylon", 0]];
            if (_currentPylon != 0) exitWith {};
            private _aircraft = missionNamespace getVariable ["ace_pylons_currentAircraft", objNull];
            if (isNull _aircraft) exitWith {};
            private _combos = missionNamespace getVariable ["ace_pylons_comboBoxes", []];
            private _rearm = (missionNamespace getVariable ["ace_pylons_rearmNewPylons", false])
                || { missionNamespace getVariable ["ace_pylons_isCurator", false] };
            {
                private _pylonIndex = _x;
                private _row = _combos param [_pylonIndex, []];
                if (_row isEqualTo []) then { continue };
                private _combo = _row select 0;
                if (isNull _combo) then { continue };
                private _magazine = _combo lbData (lbCurSel _combo);
                private _turret = [];
                private _button = _row param [2, controlNull];
                if (!isNull _button) then {
                    _turret = _button getVariable ["ace_pylons_turret", []];
                };
                private _ammo = 0;
                if (_rearm && {_magazine != ""}) then {
                    _ammo = getNumber (configFile >> "CfgMagazines" >> _magazine >> "count");
                };
                [_aircraft, _pylonIndex + 1, _magazine, _turret, _ammo] call FADE_pylon_apply;
            } forEach _pylonsToConfigure;
        };
    };

    if (!isNil "zen_pylons_fnc_handleConfirm") then {
        zen_pylons_fnc_handleConfirm = {
            params ["_ctrlButtonOK"];
            private _display = ctrlParent _ctrlButtonOK;
            private _aircraft = _display getVariable ["zen_pylons_aircraft", objNull];
            if (isNull _aircraft) exitWith {};
            private _controls = _display getVariable ["zen_pylons_controls", []];
            {
                _x params ["_ctrlCombo", "_ctrlTurret"];
                if (isNull _ctrlCombo) then { continue };
                private _magazine = _ctrlCombo lbData (lbCurSel _ctrlCombo);
                private _turretPath = [];
                if (!isNull _ctrlTurret) then {
                    _turretPath = _ctrlTurret getVariable ["zen_pylons_turretPath", []];
                };
                [_aircraft, _forEachIndex + 1, _magazine, _turretPath, -1] call FADE_pylon_apply;
            } forEach _controls;
        };
    };
};

// Runs on every machine. GetIn / controlsShifted fire where the event is raised, then this
// continues only where the aircraft is local. A failed loadout is cached so the same pair is not retried.
if (!isNil "RS_MH6V3_fnc_syncPylonOwner") then {
    FADE_pylon_mh6SyncPatched = true;
    RS_MH6V3_fnc_syncPylonOwner = {
        params [
            ["_vehicle", objNull, [objNull]],
            ["_overrides", objNull, [[], objNull]]
        ];
        if (isNull _vehicle || {!alive _vehicle}) exitWith {};
        if (!local _vehicle) exitWith {
            [_vehicle, _overrides] remoteExecCall ["RS_MH6V3_fnc_syncPylonOwner", _vehicle];
        };
        if (_overrides isEqualType []) then {
            _vehicle setVariable ["RS_MH6V3_pylonOwnerOverride", _overrides, true];
        };

        private _overrideArray = _vehicle getVariable ["RS_MH6V3_pylonOwnerOverride", []];
        private _copilot = _vehicle turretUnit [0];
        private _activeCopilot = _vehicle getVariable ["RS_MH6V3_activeCopilot", objNull];
        private _copilotHasControl = (
            !isNull _copilot
            && {
                currentPilot _vehicle isEqualTo _copilot
                || {_activeCopilot isEqualTo _copilot}
            }
        );
        private _magazines = getPylonMagazines _vehicle;
        private _turretCache = _vehicle getVariable ["RS_MH6V3_pylonTurretCache", []];
        {
            private _pylonIndex = _forEachIndex + 1;
            if (_x == "") then { continue };
            private _override = _overrideArray param [_forEachIndex, ""];
            private _wantsCopilot = switch (_override) do {
                case "copilot": {!isNull _copilot};
                case "pilot": {false};
                default {_copilotHasControl};
            };
            private _wantTurret = [[], [0]] select _wantsCopilot;
            private _cached = _turretCache param [_forEachIndex, ["", []]];
            _cached params [["_cachedMag", ""], ["_cachedTurret", []]];
            if (_cachedMag isEqualTo _x && {_cachedTurret isEqualTo _wantTurret}) then { continue };
            private _ammo = _vehicle ammoOnPylon _pylonIndex;
            private _loaded = _vehicle setPylonLoadout [_pylonIndex, _x, true, _wantTurret];
            if (_loaded) then {
                _vehicle setAmmoOnPylon [_pylonIndex, _ammo];
            } else {
                diag_log format [
                    "[FADE] RS_MH6V3 pylon %1 rejected %2 on turret %3 (not retried).",
                    _pylonIndex, _x, _wantTurret
                ];
            };
            _turretCache set [_forEachIndex, [_x, _wantTurret]];
        } forEach _magazines;
        _vehicle setVariable ["RS_MH6V3_pylonTurretCache", _turretCache, true];
    };
};
