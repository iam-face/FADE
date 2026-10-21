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

// Realistic keeps the original costs. A class missing from this config is skipped.
private _realisticSrc = [
    ["Land_BagFence_Long_F", "Sandbag fence (long)", 15, "Sandbags"],
    ["Land_BagFence_Short_F", "Sandbag fence (short)", 8, "Sandbags"],
    ["Land_BagFence_Round_F", "Sandbag fence (round)", 10, "Sandbags"],
    ["Land_HBarrier_1_F", "H-barrier (single)", 20, "Barriers"],
    ["Land_HBarrier_5_F", "H-barrier (5)", 40, "Barriers"],
    ["Land_Razorwire_F", "Razor wire", 12, "Barriers"],
    ["Land_CncBarrierMedium4_F", "Concrete barrier", 25, "Barriers"],
    ["Land_BagBunker_Small_F", "Small bag bunker", 80, "Bunkers"],
    ["Land_CamoNet_BIG_F", "Camo net (large)", 30, "Camo"],
    ["Land_PortableLight_single_F", "Portable light", 10, "Lights"]
];
private _realistic = [];
{
    _x params ["_class", "_dn", "_cost", "_sub"];
    if !(isClass (configFile >> "CfgVehicles" >> _class)) then { continue };
    _realistic pushBack [_class, _dn, _cost, 0, "", "Fortifications", _sub];
} forEach _realisticSrc;
FADE_buildCatalogRealistic = _realistic;

// Four placements. Gear, Barracks, and Vehicles share a model. The role tells them apart.
private _baseSrc = [
    ["gear", "Gear", "Land_MedicalTent_01_NATO_generic_closed_F"],
    ["barracks", "Barracks", "Land_MedicalTent_01_NATO_generic_closed_F"],
    ["vehicles", "Vehicles", "Land_MedicalTent_01_NATO_generic_closed_F"],
    ["medical", "Medical", "Land_MedicalTent_01_MTP_closed_F"]
];
private _base = [];
{
    _x params ["_role", "_dn", "_class"];
    if !(isClass (configFile >> "CfgVehicles" >> _class)) then { continue };
    _base pushBack [_class, _dn, 10, 0, "", "Base buildings", "Structures", _role];
} forEach _baseSrc;
FADE_buildCatalogBase = _base;
