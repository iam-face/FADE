// BuildCatalog.sqf - Eden props, scanned from CfgVehicles.
// One row: [class, displayName, cost, buildTime, unlock, category, subcategory]
// Category and subcategory are the Eden editor group names (Fences > Military > object).
// cost is flat. buildTime stays 0. unlock stays "" until a later function gate.

private _catNames = createHashMap;
private _subNames = createHashMap;
private _label = {
    params ["_cache", "_root", "_key", "_fallback"];
    if (_key == "") exitWith { _fallback };
    private _cached = _cache getOrDefault [_key, ""];
    if (_cached != "") exitWith { _cached };
    private _dn = getText (configFile >> _root >> _key >> "displayName");
    if (_dn == "") then { _dn = _key };
    _cache set [_key, _dn];
    _dn
};

// Men, vehicles, static weapons, logics, backpacks, and holders are not Eden props.
private _blockedParents = ["Man", "AllVehicles", "Logic", "Bag_Base", "WeaponHolder", "Animal_Base_F", "ThingEffect"];
private _rows = [];
private _index = createHashMap;

{
    private _cfg = _x;
    if (getNumber (_cfg >> "scope") < 2) then { continue };
    private _dn = getText (_cfg >> "displayName");
    if (_dn == "") then { continue };
    private _edCat = getText (_cfg >> "editorCategory");
    if (_edCat == "") then { continue };
    private _model = getText (_cfg >> "model");
    if (_model == "" || { (toLower _model) find "empty.p3d" >= 0 }) then { continue };
    private _class = configName _cfg;
    private _blocked = false;
    {
        if (_class isKindOf _x) exitWith { _blocked = true };
    } forEach _blockedParents;
    if (_blocked) then { continue };
    private _cat = [_catNames, "CfgEditorCategories", _edCat, "Other"] call _label;
    private _subKey = getText (_cfg >> "editorSubcategory");
    private _sub = [_subNames, "CfgEditorSubcategories", _subKey, "Other"] call _label;
    private _row = [_class, _dn, 10, 0, "", _cat, _sub];
    _rows pushBack _row;
    _index set [_class, _row];
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

private _keyed = _rows apply { [_x select 5, _x select 6, _x select 1, _x] };
_keyed sort true;
FADE_buildCatalog = _keyed apply { _x select 3 };
FADE_buildCatalogIndex = _index;
