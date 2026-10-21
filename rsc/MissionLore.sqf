// =============================================================================
// MissionLore.sqf — procedural mission background (flavour only; server)
// Tier 1+2: split short/long, faction+role, bundles, world-state slots, seeded RNG
// =============================================================================

// --- Role pools (always combined with {factionFriendly} / narrative {opforRole}) ---
missionNamespace setVariable ["FADE_lore_pool_bluforRole", [
    "peacekeeping detachment",
    "quick-reaction force",
    "air assault element",
    "reconnaissance team",
    "combined arms task force",
    "special operations detachment",
    "humanitarian security team",
    "forward air controller team"
]];

missionNamespace setVariable ["FADE_lore_pool_bluforRole_byType", createHashMapFromArray [
    ["CAS", ["attack aviation element", "close air support flight", "rotary-wing fires team", "armed reconnaissance flight"]],
    ["Cargo", ["logistics flight", "resupply airlift", "sustainment detachment", "forward support team"]],
    ["TroopInsert", ["airmobile insertion element", "assault aviation detachment", "heliborne lift team"]],
    ["TroopExtract", ["extraction flight", "assault aviation detachment", "recovery lift team"]],
    ["CASEVAC", ["medical evacuation flight", "aeromedical evacuation team", "DUSTOFF element"]],
    ["CSAR", ["search and rescue element", "recovery flight", "CSAR detachment"]],
    ["MineClearing", ["route clearance team", "engineer support detachment", "EOD advisory team"]],
    ["GeoGuesser", ["reconnaissance training element", "map reconnaissance team", "observer detachment"]],
    ["PointDefense", ["point defence detachment", "holding force", "quick-reaction force", "security element"]],
    ["Invasion", ["defensive holding force", "counter-attack element", "combined arms task force"]],
    ["ClearArea", ["assault element", "clearance force", "combined arms task force"]],
    ["Raid", ["raid force", "direct-action element", "strike detachment"]]
]];

missionNamespace setVariable ["FADE_lore_pool_opforRole", [
    "insurgent cell",
    "garrison force",
    "militia battalion",
    "armed faction",
    "occupying force",
    "smuggling network",
    "paramilitary unit",
    "local warlord's fighters"
]];

// Tagged bundles: [context/instigator phrase, stakes, time pressure] - picked as one coherent set
missionNamespace setVariable ["FADE_lore_bundles", createHashMapFromArray [
    ["_combat", [
        ["seized a relay station", "retake the relay station", "before reinforcements arrive"],
        ["ambushed a supply convoy", "reopen the supply route", "before they dig in"],
        ["occupied a civilian district", "clear the district", "before they settle in"],
        ["cut a road", "open that road", "before night movement"],
        ["captured a forward outpost", "retake the outpost", "before the next rotation"],
        ["established a blocking position", "break the block", "before they reinforce it"],
        ["moved heavy weapons into the area", "destroy or seize those weapons", "before nightfall"]
    ]],
    ["Raid", [
        ["seized several sites", "hit each objective in turn", "before reinforcements link up"],
        ["split its force between nearby towns", "stop them linking up", "before they mass reserves"],
        ["fortified several towns", "clear the defended sites", "before they dig in further"]
    ]],
    ["HVT", [
        ["is coordinating attacks from a building", "capture or kill the HVT", "before they relocate"],
        ["was located through signals intercept", "capture or kill the HVT", "before they move"],
        ["is meeting subordinate commanders", "capture or kill the HVT", "before the meeting ends"]
    ]],
    ["Hostage", [
        ["is holding civilians in a built-up area", "extract the hostages", "before they move the hostages"],
        ["has barricaded inside local buildings", "extract the hostages", "before they move the hostages"],
        ["is using civilians as human shields", "extract the hostages", "before they are moved"]
    ]],
    ["InterceptConvoy", [
        ["is moving supplies along the main supply route", "stop and destroy the convoy", "before it reaches its destination"],
        ["is escorting heavy weapons eastbound", "stop the column and destroy the heavy weapons vehicles", "before escorts break contact"],
        ["is using civilian traffic as cover on the MSR", "stop the convoy", "before it clears the intercept zone"]
    ]],
    ["CSAR", [
        ["has search teams sweeping toward the survivor", "extract the survivor", "before they capture or kill the survivor"],
        ["is blocking likely escape routes", "extract the survivor", "before the perimeter closes"],
        ["has air search working with ground patrols", "extract the survivor", "before the patrols reach the survivor"]
    ]],
    ["CASEVAC", [
        ["is near the casualty", "extract the casualty", "within the golden hour"],
        ["may contest the pickup", "extract the casualty", "before the casualty gets worse"],
        ["is moving toward the casualty", "extract the casualty", "before the LZ is lost"]
    ]],
    ["Invasion", [
        ["is landing on the coast", "hold the beachhead", "before follow-on waves arrive"],
        ["is pushing inland", "hold the towns inland", "before enemy forces link up"],
        ["has a foothold on the beach", "throw the assault back", "before armour is ashore"]
    ]],
    ["PointDefense", [
        ["is massing to seize the marked point", "hold the marked ground", "until the defend window closes"],
        ["is probing a downed aircraft", "hold the crash site", "before they take the site"],
        ["is pressing a halted friendly column", "hold around the convoy", "until the hold timer expires"]
    ]],
    ["_logistics", [
        ["the route runs near reported hostiles", "complete the lift", "within the assigned flight window"],
        ["the LZ choices are few", "complete the lift", "before the receiving unit moves"],
        ["ground security at the site is thin", "complete the lift", "before the window closes"]
    ]],
    ["Cargo", [
        ["forward units are short of supplies", "deliver the cargo", "before the stocks run out"],
        ["the drop zone is open ground", "deliver the cargo", "within this lift window"],
        ["receiving troops are about to move", "deliver the cargo", "before the receiving party leaves"]
    ]],
    ["MineClearing", [
        ["has mined routes in the area", "clear a lane", "before the convoys move"],
        ["has laid mines on the approaches", "clear a lane", "before night movement"],
        ["has mined the MSR", "clear a lane", "before the convoys move"]
    ]],
    ["GeoGuesser", [
        ["is on a map position drill", "mark your position on the map", "before the timer ends"],
        ["is checking map reading", "mark your position on the map", "before the timer ends"],
        ["is on a familiarisation patrol", "mark your position on the map", "before the timer ends"]
    ]]
]];

missionNamespace setVariable ["FADE_lore_bundleCategory", createHashMapFromArray [
    ["Raid", "Raid"],
    ["HVT", "HVT"],
    ["Hostage", "Hostage"],
    ["InterceptConvoy", "InterceptConvoy"],
    ["CSAR", "CSAR"],
    ["CASEVAC", "CASEVAC"],
    ["Invasion", "Invasion"],
    ["PointDefense", "PointDefense"],
    ["Cargo", "Cargo"],
    ["MineClearing", "MineClearing"],
    ["GeoGuesser", "GeoGuesser"],
    ["TroopInsert", "_logistics"],
    ["TroopExtract", "_logistics"]
]];

missionNamespace setVariable ["FADE_lore_pool_uncertainty_combat", [
    "Reports indicate",
    "HUMINT suggests",
    "SIGINT places",
    "Current picture:",
    "Latest reports show"
]];

missionNamespace setVariable ["FADE_lore_pool_uncertainty_logistics", [
    "Mission order states",
    "Tasking directs",
    "Ops cell confirms",
    "FRAGO:",
    "Current tasking requires"
]];

// Per-type templates: [short headline, situation sentence, commander's intent sentence]
missionNamespace setVariable ["FADE_lore_templates", createHashMapFromArray [
    ["Raid", [
        ["{opNameUpper} - multi-site raid near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}). Enemy strength is {echelon}. {civSituation} The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: coordinated strikes near {region}.",
         "Several objectives are active around {region}. {articleOpforRoleCap} {instigator}. Enemy strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["Operation", [
        ["{opNameUpper} - clearance near {region}.",
         "{articleOpforRoleCap} holds several settlements near {region} (grid {grid}). {civSituation} Contact strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: zones near {region}.",
         "{articleOpforRoleCap} is consolidating around {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["Invasion", [
        ["{opNameUpper} - defensive stand near {region}.",
         "{articleOpforRoleCap} {instigator} near {region}. {civSituation} Assault strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: contain the push - {region}.",
         "{articleOpforRoleCap} is attacking from the {region} sector (grid {grid}).",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["PointDefense", [
        ["{opNameUpper} - hold point near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}). Assault strength is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: point defence - {region}.",
         "The marked point is near {region}. {articleOpforRoleCap} will attack with infantry and vehicles.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."],
        ["{opNameUpper}: defend the site - {region}.",
         "The site near {region} (grid {grid}) is a timed defence against {articleOpforRole}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["AreaOfOperations", [
        ["{opNameUpper} - AO near {region}.",
         "{articleOpforRoleCap} is active near {region} (grid {grid}). Enemy strength is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: seize objectives near {region}.",
         "The sector is {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["HVT", [
        ["{opNameUpper} - HVT near {region}.",
         "The {factionEnemy} {opforRole} commander {instigator} near {region} (grid {grid}). {civSituation} Local security is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. Confirm the identity before you shoot."],
        ["{opNameUpper}: priority target - {region}.",
         "{factionEnemy} leadership is traced to {region}. {weatherPhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["Hostage", [
        ["{opNameUpper} - hostages near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}). {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. Watch your fires around civilians."],
        ["{opNameUpper}: hostage recovery - {region}.",
         "{articleOpforRoleCap} holds the hostages near {region}. Enemy strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["ClearArea", [
        ["{opNameUpper} - clear {region}.",
         "{articleOpforRoleCap} has fortified positions near {region} (grid {grid}). The garrison is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."],
        ["{opNameUpper}: clearance - {region}.",
         "The {opforRole} holds ground near {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["SearchDestroy", [
        ["{opNameUpper} - caches near {region}.",
         "{articleOpforRoleCap} has stockpiles near {region} (grid {grid}). The guard force is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: search and destroy - {region}.",
         "Caches linked to {articleOpforRole} are near {region}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["AssetRetrieval", [
        ["{opNameUpper} - asset recovery near {region}.",
         "{articleOpforRoleCap} holds the equipment near {region} (grid {grid}). Security is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: retrieve equipment - {region}.",
         "{factionEnemy} holds friendly equipment near {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["AssetRetrievalVeh", [
        ["{opNameUpper} - vehicle recovery near {region}.",
         "The vehicle is at a road site near {region} (grid {grid}). Dismounted security is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["InterceptConvoy", [
        ["{opNameUpper} - convoy intercept near {region}.",
         "{factionEnemy} {instigator}. The intercept is near {region} (grid {grid}).",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: stop the column - {region}.",
         "{factionEnemy} logistics are moving near {region}. Escort strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["CAS", [
        ["{opNameUpper} - CAS near {region}.",
         "{articleOpforRoleCap} is pressing friendly positions near {region} (grid {grid}). {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. Talk fires with the friendlies on the ground."],
        ["{opNameUpper}: fire support - {region}.",
         "Friendly troops near {region} are in contact with {articleOpforRole}. Enemy strength is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["CSAR", [
        ["{opNameUpper} - CSAR near {region}.",
         "Isolated personnel are down near {region} (grid {grid}). {articleOpforRoleCap} {instigator}. {civSituation} {weatherPhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: recover survivor - {region}.",
         "A survivor is isolated near {region}. {articleOpforRoleCap} patrols are active. The threat is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["EscapeEvasion", [
        ["{opNameUpper} - E&E near {region}.",
         "Separated friendly personnel are evading {articleOpforRole} near {region} (grid {grid}). {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: extract evaders - {region}.",
         "{articleOpforRoleCap} patrols are sweeping near {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["TroopInsert", [
        ["{opNameUpper} - insertion near {region}.",
         "The insert LZ is near {region} (grid {grid}). {instigatorCap}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: heliborne insert - {region}.",
         "The LZ is near {region}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["TroopExtract", [
        ["{opNameUpper} - extraction near {region}.",
         "The ground team is near {region} (grid {grid}). {instigatorCap}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: troop extract - {region}.",
         "The extraction LZ is near {region}. {civSituation} The threat is {echelon}.",
         "{factionFriendly} {bluforRole} will extract the team {timeHook} during {timePhase}."]
    ]],
    ["Cargo", [
        ["{opNameUpper} - resupply near {region}.",
         "The cargo point is near {region} (grid {grid}). {instigatorCap}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: logistics run - {region}.",
         "The receiving party is near {region}. {weatherPhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["CASEVAC", [
        ["{opNameUpper} - CASEVAC near {region}.",
         "A casualty needs lift near {region} (grid {grid}). {articleOpforRoleCap} {instigator}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."],
        ["{opNameUpper}: medical evacuation - {region}.",
         "The wounded are near {region}. The threat is {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["MineClearing", [
        ["{opNameUpper} - route clearance near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}).",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. Treat the route as hostile until you clear it."],
        ["{opNameUpper}: breach lane - {region}.",
         "A hazard is on a route near {region}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["GeoGuesser", [
        ["TRAINING - {opNameUpper} near {region}.",
         "{factionFriendly} {bluforRole} {instigator} near {region} (grid {grid}). No enemy is task-organised.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: map recon exercise - {region}.",
         "The drill is near {region}. No enemy is task-organised. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["_default", [
        ["{opNameUpper} - tasking near {region}.",
         "{articleOpforRoleCap} is active near {region} (grid {grid}). Enemy strength is {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: mission near {region}.",
         "The task is near {region}. The objective is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]]
]];

FADE_lore_hashStr = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = str _s };
    private _h = 0;
    { _h = ((_h * 31) + _x) % 2147483647 } forEach (toArray _s);
    _h
};

FADE_lore_computeSeed = {
    params ["_missionType", "_destPos", "_opName"];
    private _grid = if (_destPos isEqualType [] && { count _destPos >= 2 }) then { mapGridPosition _destPos } else { "000000" };
    private _dateStr = if (!isNil "date") then { str date } else { "0" };
    abs (
        ([_missionType] call FADE_lore_hashStr) +
        ([_grid] call FADE_lore_hashStr) +
        ([_opName] call FADE_lore_hashStr) +
        ([_dateStr] call FADE_lore_hashStr)
    )
};

FADE_lore_seededIndex = {
    params ["_seed", "_salt", "_count"];
    if (_count < 1) exitWith { 0 };
    abs (_seed + _salt * 9973) % _count
};

FADE_lore_seededPick = {
    params ["_pool", "_seed", "_salt"];
    if (_pool isEqualTo []) exitWith { "" };
    private _idx = [_seed, _salt, count _pool] call FADE_lore_seededIndex;
    _pool select _idx
};

FADE_lore_capitalize = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = str _s };
    if (_s == "") exitWith { "" };
    toUpper (_s select [0, 1]) + (_s select [1, count _s - 1])
};

FADE_lore_withArticle = {
    params ["_phrase", ["_capitalize", false]];
    if (_phrase == "") exitWith { if (_capitalize) then { "Unknown" } else { "unknown" } };
    private _lower = toLower (_phrase select [0, 1]);
    private _article = if (_lower in ["a", "e", "i", "o", "u"]) then { "an" } else { "a" };
    private _out = _article + " " + _phrase;
    if (_capitalize) then { [_out] call FADE_lore_capitalize } else { _out }
};

FADE_lore_echelonLabel = {
    params ["_n"];
    switch (true) do {
        case (_n <= 0): { "minimal" };
        case (_n <= 3): { "fire team or less" };
        case (_n <= 8): { "fire team to squad" };
        case (_n <= 15): { "squad" };
        case (_n <= 28): { "squad to platoon" };
        case (_n <= 50): { "platoon" };
        case (_n <= 85): { "platoon to company" };
        case (_n <= 140): { "company" };
        default { "company or larger" };
    };
};

FADE_lore_opforBaseline = {
    params ["_missionType"];
    switch (_missionType) do {
        case "TroopInsert": { 10 };
        case "TroopExtract": { 12 };
        case "CASEVAC": { 14 };
        case "CSAR": { 16 };
        case "Cargo": { 0 };
        case "CAS": { 24 };
        case "HVT": { 18 };
        case "Hostage": { 20 };
        case "ClearArea": { 26 };
        case "SearchDestroy": { 20 };
        case "InterceptConvoy": { 14 };
        case "MineClearing": { 6 };
        case "AssetRetrieval";
        case "AssetRetrievalVeh": { 14 };
        case "AreaOfOperations": { 30 };
        case "Operation": { 36 };
        case "Raid": { 28 };
        case "Invasion": { 40 };
        case "PointDefense": { 24 };
        case "EscapeEvasion": { 22 };
        case "GeoGuesser": { 0 };
        default { 10 };
    };
};

FADE_lore_weatherPhrase = {
    params ["_weather"];
    switch (_weather) do {
        case "Overcast": { "Overcast cuts long-range observation" };
        case "Foggy": { "Fog cuts visibility and slows movement" };
        case "Rain": { "Rain cuts visibility for flying and sensors" };
        case "Storm": { "Storms cut the window for helicopters" };
        case "FaceMission": { "Weather is the Face mission profile" };
        default { "The weather is fit for the task" };
    };
};

FADE_lore_timePhase = {
    params ["_hour"];
    if (_hour >= 5 && _hour < 8) exitWith { "dawn" };
    if (_hour < 17) exitWith { "daylight hours" };
    if (_hour < 20) exitWith { "dusk" };
    "hours of darkness"
};

FADE_lore_distancePhrase = {
    params ["_distM"];
    switch (true) do {
        case (_distM < 3000): { "close to friendly base" };
        case (_distM < 8000): { "in the outer operating area" };
        default { "far from base in contested ground" };
    };
};

FADE_lore_civSituation = {
    params ["_destPos", "_region"];
    if (!(missionNamespace getVariable ["FADE_civiliansEnabled", true])) exitWith {
        "Civilians are not expected in the objective area."
    };
    private _nearestD = 1e15;
    private _nearestMeta = createHashMap;
    {
        private _obj = missionNamespace getVariable [_x, objNull];
        if (!isNull _obj) then {
            private _d = _destPos distance2D _obj;
            if (_d < _nearestD) then {
                _nearestD = _d;
                private _meta = missionNamespace getVariable ["FADE_civZoneMeta", createHashMap] getOrDefault [_x, createHashMap];
                _nearestMeta = _meta;
            };
        };
    } forEach (missionNamespace getVariable ["FADE_civTriggerNames", []]);
    if (_nearestD > 2500) exitWith {
        "Civilian activity is sparse. Confirm identities before you shoot."
    };
    private _lt = _nearestMeta getOrDefault ["locType", ""];
    switch (_lt) do {
        case "NameCityCapital";
        case "NameCity": { format ["Civilians are dense around %1. Watch your fires.", _region] };
        case "NameVillage": { format ["Village traffic is near %1. Locals may watch the force.", _region] };
        default { "Civilians may be present. Confirm identities before you shoot." };
    };
};

FADE_lore_isLogisticsType = {
    params ["_missionType"];
    _missionType in ["Cargo", "TroopInsert", "TroopExtract", "CASEVAC", "GeoGuesser"]
};

FADE_lore_escapeForFormat = {
    params ["_s"];
    if !(_s isEqualType "") then { _s = str _s };
    private _parts = _s splitString "%";
    _parts joinString "%%"
};

FADE_lore_ensurePeriod = {
    params ["_s"];
    if (_s isEqualTo "") exitWith { "" };
    private _last = toLower (_s select [(count _s) - 1, 1]);
    if (_last in [".", "!", "?"]) then { _s } else { _s + "." }
};

FADE_lore_formatEnemyLoreLine = {
    params ["_ctx", "_uncertainty"];
    private _enemy = _ctx getOrDefault ["factionEnemy", "hostile forces"];
    private _articleRole = _ctx getOrDefault ["articleOpforRole", "the hostile force"];
    private _region = _ctx getOrDefault ["region", "the area"];
    private _instigator = _ctx getOrDefault ["instigator", ""];
    private _missionType = _ctx getOrDefault ["missionType", ""];
    private _colonLead = _uncertainty select [count _uncertainty - 1, 1] == ":";
    private _joiner = if (_colonLead) then { " " } else { " that " };
    private _line = "";
    if (_missionType == "GeoGuesser") then {
        private _fact = "the task is a map drill near " + _region;
        if (_colonLead) then { _fact = [_fact] call FADE_lore_capitalize };
        _line = format ["%1%2%3", _uncertainty, _joiner, _fact];
    } else {
        if (_instigator == "") then {
            _line = format ["%1%2%3, %4, is active near %5", _uncertainty, _joiner, _enemy, _articleRole, _region];
        } else {
            private _head = toLower _instigator;
            private _ownClause = (_head find "the " == 0) || { _head find "ground " == 0 } || { _head find "forward " == 0 } || { _head find "receiving " == 0 };
            if (_ownClause) then {
                private _fact = if (_colonLead) then { [_instigator] call FADE_lore_capitalize } else { _instigator };
                _line = format ["%1%2%3", _uncertainty, _joiner, _fact];
            } else {
                _line = format ["%1%2%3 %4", _uncertainty, _joiner, _enemy, _instigator];
            };
        };
    };
    [_line] call FADE_lore_ensurePeriod
};

// Structured BACKGROUND block for SMEAC (enemy lore, threat assessment, commander's intent).
FADE_lore_formatSmeacHtml = {
    params ["_enemyLoreLine", "_threatAssess", "_intent"];
    if (_threatAssess isEqualTo "" && { _intent isEqualTo "" }) exitWith { "" };
    private _srcCol = "#8BA4BE";
    private _bodyCol = "#B0B0B0";
    private _lore = [_enemyLoreLine] call FADE_lore_ensurePeriod;
    private _threat = [_threatAssess] call FADE_lore_ensurePeriod;
    private _intentTxt = [_intent] call FADE_lore_ensurePeriod;
    format [
        "<t align='left' color='#FFD166'>BACKGROUND</t><br/>" +
        "<t align='left' color='%1'>- %2</t><br/>" +
        "<t align='left' color='%3'>- Threat assessment: %4</t><br/>" +
        "<t align='left' color='%3'>- Commander's intent: %5</t>",
        _srcCol, _lore,
        _bodyCol, _threat, _intentTxt
    ]
};

FADE_lore_formatDiaryPlain = {
    params ["_enemyLoreLine", "_threatAssess", "_intent"];
    private _nl = toString [10];
    private _lore = [_enemyLoreLine] call FADE_lore_ensurePeriod;
    private _threat = [_threatAssess] call FADE_lore_ensurePeriod;
    private _intentTxt = [_intent] call FADE_lore_ensurePeriod;
    format [
        "%1%2%2Threat assessment: %3%2%2Commander's intent: %4",
        _lore, _nl, _threat, _intentTxt
    ]
};

// SMEAC Situation append — pre-formatted HTML from FADE_lore_generate (third return value).
FADE_lore_smeacBlockHtml = {
    params [["_smeacHtml", ""]];
    if (_smeacHtml isEqualTo "") then {
        _smeacHtml = missionNamespace getVariable ["FADE_missionRun_loreSmeacHtml", ""];
    };
    _smeacHtml
};

// SMEAC Situation append - lore BACKGROUND is separate (FADE_lore_formatSmeacHtml); keep API stable.
FADE_lore_appendSituationHtml = {
    params ["_situationHtml", ["_smeacHtml", ""]];
    _situationHtml
};

FADE_lore_applySlots = {
    params ["_template", "_ctx"];
    private _slotOrder = [
        "factionFriendlyCap", "factionEnemyCap", "articleOpforRoleCap", "instigatorCap",
        "articleOpforRole", "factionFriendly", "factionEnemy", "opNameUpper", "opName",
        "bluforRole", "opforRole", "instigator", "stakes", "timeHook", "region", "grid",
        "echelon", "weatherPhrase", "timePhase", "distancePhrase", "civSituation", "uncertainty", "missionType"
    ];
    {
        private _tok = "{" + _x + "}";
        private _val = _ctx getOrDefault [_x, ""];
        if (_val == "") then { _val = "unknown" };
        while { (_template find _tok) >= 0 } do {
            private _idx = _template find _tok;
            private _before = _template select [0, _idx];
            private _after = _template select [_idx + (count _tok), (count _template) - _idx - (count _tok)];
            _template = _before + _val + _after;
        };
    } forEach _slotOrder;
    _template
};

FADE_lore_buildContext = {
    params ["_missionType", "_destPos", "_opName", "_seed"];
    private _ctx = createHashMap;
    private _topo = [_destPos] call (missionNamespace getVariable ["FADE_getTopographySummary", { ["UNKNOWN", "unknown terrain"] }]);
    private _region = _topo param [1, "unknown terrain"];
    private _grid = _topo param [0, "UNKNOWN"];
    private _fc = missionNamespace getVariable ["FADE_scenarioFriendlyFaction", "BLU_F"];
    private _ec = missionNamespace getVariable ["FADE_scenarioEnemyFaction", "OPF_F"];
    private _factionFn = missionNamespace getVariable ["FADE_getFactionDisplayName", { params ["_f"]; _f }];
    private _factionFriendly = missionNamespace getVariable ["FADE_smeacFriendlyLabel", "CTB"];
    private _factionEnemy = [_ec] call _factionFn;
    private _bluPool = (missionNamespace getVariable ["FADE_lore_pool_bluforRole_byType", createHashMap]) getOrDefault [
        _missionType,
        missionNamespace getVariable ["FADE_lore_pool_bluforRole", []]
    ];
    private _opforPool = missionNamespace getVariable ["FADE_lore_pool_opforRole", []];
    private _bluforRole = [_bluPool, _seed, 3] call FADE_lore_seededPick;
    private _opforRole = [_opforPool, _seed, 5] call FADE_lore_seededPick;
    private _bundleCat = (missionNamespace getVariable ["FADE_lore_bundleCategory", createHashMap]) getOrDefault [
        _missionType,
        if ([_missionType] call FADE_lore_isLogisticsType) then { "_logistics" } else { "_combat" }
    ];
    private _bundlesMap = missionNamespace getVariable ["FADE_lore_bundles", createHashMap];
    private _bundles = _bundlesMap getOrDefault [_bundleCat, _bundlesMap getOrDefault ["_combat", []]];
    private _bundle = if (_bundles isEqualTo []) then { ["", "", ""] } else {
        private _bIdx = [_seed, 11, count _bundles] call FADE_lore_seededIndex;
        _bundles select _bIdx
    };
    private _instigator = _bundle param [0, ""];
    private _stakes = _bundle param [1, ""];
    private _timeHook = _bundle param [2, ""];
    private _baseline = [_missionType] call FADE_lore_opforBaseline;
    private _factor = if ((_seed % 2) == 0) then { 0.8 } else { 1.2 };
    private _estCount = (round (_baseline * _factor)) max 0;
    private _echelon = [_estCount] call FADE_lore_echelonLabel;
    private _weather = missionNamespace getVariable ["FADE_scenarioWeather", "Clear"];
    private _hour = missionNamespace getVariable ["FADE_scenarioTime", 12];
    private _base = missionNamespace getVariable ["FADE_basePos", [0, 0, 0]];
    private _distM = if (count _destPos >= 2 && { count _base >= 2 }) then { _destPos distance2D _base } else { 5000 };
    private _uncertaintyPool = if ([_missionType] call FADE_lore_isLogisticsType || { _missionType == "MineClearing" }) then {
        missionNamespace getVariable ["FADE_lore_pool_uncertainty_logistics", []]
    } else {
        missionNamespace getVariable ["FADE_lore_pool_uncertainty_combat", []]
    };
    private _uncertainty = [_uncertaintyPool, _seed, 13] call FADE_lore_seededPick;
    private _instigatorCap = if (_instigator == "") then { "" } else { [_instigator] call FADE_lore_capitalize };
    _ctx set ["opName", _opName];
    _ctx set ["opNameUpper", toUpper _opName];
    _ctx set ["region", _region];
    _ctx set ["grid", _grid];
    _ctx set ["bluforRole", _bluforRole];
    _ctx set ["opforRole", _opforRole];
    _ctx set ["factionFriendly", _factionFriendly];
    _ctx set ["factionEnemy", _factionEnemy];
    _ctx set ["factionFriendlyCap", _factionFriendly];
    _ctx set ["factionEnemyCap", [_factionEnemy] call FADE_lore_capitalize];
    _ctx set ["articleOpforRole", [_opforRole, false] call FADE_lore_withArticle];
    _ctx set ["articleOpforRoleCap", [_opforRole, true] call FADE_lore_withArticle];
    _ctx set ["instigator", _instigator];
    _ctx set ["instigatorCap", _instigatorCap];
    _ctx set ["stakes", _stakes];
    _ctx set ["timeHook", _timeHook];
    _ctx set ["echelon", _echelon];
    _ctx set ["weatherPhrase", [_weather] call FADE_lore_weatherPhrase];
    _ctx set ["timePhase", [_hour] call FADE_lore_timePhase];
    _ctx set ["distancePhrase", [_distM] call FADE_lore_distancePhrase];
    _ctx set ["civSituation", [_destPos, _region] call FADE_lore_civSituation];
    _ctx set ["uncertainty", _uncertainty];
    _ctx set ["missionType", _missionType];
    _ctx
};

// Commander's intent sentence only (hqMainBoard, GUIs). Matches FADE_lore_generate seed/templates.
FADE_lore_commanderIntentLine = {
    params ["_missionType", "_destPos", ["_opName", ""]];
    if (!(_missionType isEqualType "") || { _missionType == "" }) exitWith { "" };
    if (!(_destPos isEqualType []) || { count _destPos < 2 }) then { _destPos = [0, 0, 0] };
    if !(_opName isEqualType "") then { _opName = "" };
    private _seed = [_missionType, _destPos, _opName] call FADE_lore_computeSeed;
    private _ctx = [_missionType, _destPos, _opName, _seed] call FADE_lore_buildContext;
    private _templatesMap = missionNamespace getVariable ["FADE_lore_templates", createHashMap];
    private _templates = _templatesMap getOrDefault [_missionType, _templatesMap getOrDefault ["_default", []]];
    if (_templates isEqualTo []) exitWith { "" };
    private _tplIdx = [_seed, 17, count _templates] call FADE_lore_seededIndex;
    private _triple = _templates select _tplIdx;
    if (!(_triple isEqualType []) || { count _triple < 3 }) exitWith { "" };
    private _intentTpl = _triple param [2, ""];
    private _intent = [_intentTpl, _ctx] call FADE_lore_applySlots;
    [_intent] call FADE_lore_ensurePeriod
};

FADE_lore_generate = {
    params ["_missionType", "_destPos", ["_opName", ""]];
    if (!(_missionType isEqualType "") || { _missionType == "" }) exitWith { ["", "", ""] };
    if (!(_destPos isEqualType []) || { count _destPos < 2 }) then { _destPos = [0, 0, 0] };
    if !(_opName isEqualType "") then { _opName = "" };
    private _seed = [_missionType, _destPos, _opName] call FADE_lore_computeSeed;
    private _ctx = [_missionType, _destPos, _opName, _seed] call FADE_lore_buildContext;
    private _templatesMap = missionNamespace getVariable ["FADE_lore_templates", createHashMap];
    private _templates = _templatesMap getOrDefault [_missionType, _templatesMap getOrDefault ["_default", []]];
    if (_templates isEqualTo []) exitWith { ["", "", ""] };
    private _tplIdx = [_seed, 17, count _templates] call FADE_lore_seededIndex;
    private _triple = _templates select _tplIdx;
    if (!(_triple isEqualType []) || { count _triple < 3 }) exitWith { ["", "", ""] };
    _triple params ["_shortTpl", "_sitTpl", "_intentTpl"];
    private _situation = [_sitTpl, _ctx] call FADE_lore_applySlots;
    private _intent = [_intentTpl, _ctx] call FADE_lore_applySlots;
    private _short = [_shortTpl, _ctx] call FADE_lore_applySlots;
    private _uncertainty = _ctx getOrDefault ["uncertainty", "Reports indicate"];
    private _enemyLoreLine = [_ctx, _uncertainty] call FADE_lore_formatEnemyLoreLine;
    private _diaryPlain = [_enemyLoreLine, _situation, _intent] call FADE_lore_formatDiaryPlain;
    private _smeacHtml = [_enemyLoreLine, _situation, _intent] call FADE_lore_formatSmeacHtml;
    if (count _short > 120) then { _short = (_short select [0, 117]) + "..." };
    [_short, _diaryPlain, _smeacHtml]
};

missionNamespace setVariable ["FADE_lore_hashStr", FADE_lore_hashStr];
missionNamespace setVariable ["FADE_lore_computeSeed", FADE_lore_computeSeed];
missionNamespace setVariable ["FADE_lore_buildContext", FADE_lore_buildContext];
missionNamespace setVariable ["FADE_lore_applySlots", FADE_lore_applySlots];
missionNamespace setVariable ["FADE_lore_escapeForFormat", FADE_lore_escapeForFormat];
missionNamespace setVariable ["FADE_lore_ensurePeriod", FADE_lore_ensurePeriod];
missionNamespace setVariable ["FADE_lore_formatEnemyLoreLine", FADE_lore_formatEnemyLoreLine];
missionNamespace setVariable ["FADE_lore_formatSmeacHtml", FADE_lore_formatSmeacHtml];
missionNamespace setVariable ["FADE_lore_formatDiaryPlain", FADE_lore_formatDiaryPlain];
missionNamespace setVariable ["FADE_lore_smeacBlockHtml", FADE_lore_smeacBlockHtml];
missionNamespace setVariable ["FADE_lore_appendSituationHtml", FADE_lore_appendSituationHtml];
missionNamespace setVariable ["FADE_lore_commanderIntentLine", FADE_lore_commanderIntentLine];
missionNamespace setVariable ["FADE_lore_generate", FADE_lore_generate];
