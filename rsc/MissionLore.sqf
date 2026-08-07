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
        ["cut off a key road", "open that road again", "before night movement"],
        ["captured a forward outpost", "retake the outpost", "before the next rotation"],
        ["established a blocking position", "break the block", "while radios still work"],
        ["moved heavy weapons into the area", "destroy or seize those weapons", "before nightfall"]
    ]],
    ["Raid", [
        ["seized several sites in the area", "hit each objective in turn", "before reinforcements link up"],
        ["split forces across nearby towns", "keep them from linking up", "before they mass reserves"],
        ["fortified several towns", "clear the defended sites", "before they dig in further"]
    ]],
    ["HVT", [
        ["is coordinating attacks from a hidden location", "capture or kill the HVT", "before they relocate"],
        ["was located through signals intercept", "take the target and collect any intel", "before the trail goes cold"],
        ["is meeting subordinate commanders", "strike while they are still there", "before the meeting breaks up"]
    ]],
    ["Hostage", [
        ["is holding civilians in a built-up area", "get the hostages out alive", "before the captors get violent"],
        ["has barricaded inside local buildings", "secure the hostages and pin the captors", "before a deadline passes"],
        ["is using civilians as human shields", "isolate the captors and free the hostages", "before they are moved"]
    ]],
    ["InterceptConvoy", [
        ["is moving supplies along the main supply route", "stop and destroy the convoy", "before it reaches its destination"],
        ["is escorting heavy weapons eastbound", "halt the column and wreck the priority vehicles", "before escorts break contact"],
        ["is using civilian traffic as cover on the MSR", "find and stop the convoy", "before it clears the intercept zone"]
    ]],
    ["CSAR", [
        ["has search teams sweeping toward the survivor", "recover the isolated personnel", "before they are captured or killed"],
        ["is blocking likely escape routes", "extract the survivor under fire", "before the perimeter closes"],
        ["has air search working with ground patrols", "reach the survivor first", "before contact is lost"]
    ]],
    ["CASEVAC", [
        ["has wounded needing urgent lift", "get the casualty to higher care", "within the golden hour"],
        ["may contest the pickup site", "finish the medical evacuation", "before the casualty worsens"],
        ["is probing toward the casualty", "stabilise and extract the patient", "before the LZ is lost"]
    ]],
    ["Invasion", [
        ["is landing assault echelons on the coast", "hold the beachhead before it grows", "before follow-on waves arrive"],
        ["is pushing inland from a lodgement", "hold the key towns", "before enemy forces link up"],
        ["has established an initial foothold", "throw the assault back", "before armour is ashore"]
    ]],
    ["PointDefense", [
        ["is massing to seize a contested point", "hold the marked ground against assault waves", "until the defend window closes"],
        ["is probing a downed aircraft site", "deny the enemy the crash site", "before recovery assets arrive"],
        ["is pressing a halted friendly column", "protect the stranded convoy", "until the hold timer expires"]
    ]],
    ["_logistics", [
        ["the route runs near reported hostiles", "finish the lift without delay", "within the assigned flight window"],
        ["LZ options look limited", "get the package in on the first workable approach", "before the receiving unit moves"],
        ["ground security at the site is thin", "insert or extract as briefed", "before conditions get worse"]
    ]],
    ["Cargo", [
        ["forward units are short on critical supplies", "deliver the cargo to the receiving party", "before stocks run out"],
        ["the drop zone is active but exposed", "complete the resupply run", "within the current lift window"],
        ["receiving troops are about to move", "get the load on the ground", "before the site is abandoned"]
    ]],
    ["MineClearing", [
        ["has mined key routes through the area", "clear a safe lane for follow-on forces", "before convoys commit"],
        ["has laid mines on likely approach routes", "confirm cleared lanes", "before night movement begins"],
        ["has blocked movement on the MSR", "breach or bypass the hazard", "before logistics stop"]
    ]],
    ["GeoGuesser", [
        ["needs a terrain and settlement check", "finish the map recon drill", "within the exercise window"],
        ["tests map reading and orientation", "find the assigned grid feature", "before the training period ends"],
        ["is a non-combat familiarisation task", "run the recon drill as briefed", "during daylight hours"]
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
         "{instigatorCap} in the {region} area (grid {grid}). Estimated enemy presence: {echelon}. {civSituation} Ops are {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}. {weatherPhrase}."],
        ["{opNameUpper}: coordinated strikes near {region}.",
         "Multiple {opforRole} objectives are active around {region}. {instigatorCap}. Enemy strength assessed at {echelon}.",
         "{factionFriendly} {bluforRole} is cleared to {stakes} {timeHook}."]
    ]],
    ["Operation", [
        ["{opNameUpper} - clearance near {region}.",
         "{articleOpforRoleCap} holds several settlements near {region} (grid {grid}). {civSituation} Contact expected at {echelon} strength.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: zone ops - {region}.",
         "{articleOpforRoleCap} is consolidating around {region}. Activity is {distancePhrase} from friendly base.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook} during {timePhase}."]
    ]],
    ["Invasion", [
        ["{opNameUpper} - defensive stand near {region}.",
         "{articleOpforRoleCap} {instigator} toward {region}. {civSituation} Assault strength estimated at {echelon}.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: contain enemy push - {region}.",
         "{articleOpforRoleCap} is attacking from the {region} sector (grid {grid}).",
         "{factionFriendly} {bluforRole} is ordered to {stakes} {timeHook} during {timePhase}."]
    ]],
    ["PointDefense", [
        ["{opNameUpper} — hold point near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}). Assault waves assessed at {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: point defence — {region}.",
         "Friendly forces must occupy and hold a marked point near {region}. {articleOpforRoleCap} is expected to contest the ground with infantry and vehicle-borne assaults.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."],
        ["{opNameUpper}: defend the site — {region}.",
         "A critical site near {region} (grid {grid}) requires a timed defence against {articleOpforRole}. Area is {distancePhrase}.",
         "{factionFriendly} {bluforRole} is ordered to {stakes} {timeHook}."]
    ]],
    ["AreaOfOperations", [
        ["{opNameUpper} - AO near {region}.",
         "{articleOpforRoleCap} activity near {region} (grid {grid}); enemy at roughly {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: seize objectives near {region}.",
         "Command assigns {factionFriendly} {bluforRole} to the {region} sector. Area is {distancePhrase}.",
         "Priority is to {stakes} {timeHook} during {timePhase}."]
    ]],
    ["HVT", [
        ["{opNameUpper} - HVT near {region}.",
         "{factionEnemy} {opforRole} commander {instigator} near {region} (grid {grid}). {civSituation} Local security at {echelon} level.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}; positive identification required."],
        ["{opNameUpper}: high-value target - {region}.",
         "{factionEnemy} leadership has been traced to {region}. {weatherPhrase}.",
         "{factionFriendly} {bluforRole} is tasked to {stakes} {timeHook} during {timePhase}."]
    ]],
    ["Hostage", [
        ["{opNameUpper} - hostages near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}). {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}; watch your fires around civilians."],
        ["{opNameUpper}: hostage recovery - {region}.",
         "Hostages are believed held by {articleOpforRole} near {region}. Enemy presence: {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["ClearArea", [
        ["{opNameUpper} - clear {region}.",
         "{articleOpforRoleCap} has fortified positions near {region} (grid {grid}). Estimated garrison: {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook} during {timePhase}."],
        ["{opNameUpper}: clearance - {region}.",
         "Enemy {opforRole} near {region} needs deliberate clearance. Area is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["SearchDestroy", [
        ["{opNameUpper} - caches near {region}.",
         "{articleOpforRoleCap} has stockpiles near {region} (grid {grid}). Guard force assessed at {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {civSituation}"],
        ["{opNameUpper}: search and destroy - {region}.",
         "Caches linked to {articleOpforRole} are reported near {region}.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook} during {timePhase}."]
    ]],
    ["AssetRetrieval", [
        ["{opNameUpper} - asset recovery near {region}.",
         "Priority gear is held by {articleOpforRole} near {region} (grid {grid}). Security at {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}; secure and extract the package."],
        ["{opNameUpper}: retrieve equipment - {region}.",
         "{factionEnemy} captured friendly equipment near {region}. Area is {distancePhrase}.",
         "{factionFriendly} {bluforRole} is tasked to {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["AssetRetrievalVeh", [
        ["{opNameUpper} - vehicle recovery near {region}.",
         "A priority vehicle is held at a road site near {region} (grid {grid}). Dismounted security at {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["InterceptConvoy", [
        ["{opNameUpper} - convoy intercept near {region}.",
         "{factionEnemy} {instigator}. Best intercept window is near {region} (grid {grid}).",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: stop the column - {region}.",
         "{factionEnemy} logistics are moving near {region}. Escort strength roughly {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["CAS", [
        ["{opNameUpper} - CAS near {region}.",
         "{articleOpforRoleCap} is pressing friendly positions near {region} (grid {grid}). {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}; talk fires with friendlies on the ground."],
        ["{opNameUpper}: fire support - {region}.",
         "Friendly troops near {region} are in contact with {articleOpforRole}. Enemy strength about {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["CSAR", [
        ["{opNameUpper} - CSAR near {region}.",
         "Isolated personnel are down near {region} (grid {grid}). {articleOpforRoleCap} {instigator}.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {civSituation} {weatherPhrase}."],
        ["{opNameUpper}: recover survivor - {region}.",
         "A survivor is isolated near {region}. {articleOpforRoleCap} patrols are active; threat at {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["EscapeEvasion", [
        ["{opNameUpper} - E&E near {region}.",
         "Separated friendly personnel are evading {articleOpforRole} near {region} (grid {grid}).",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {civSituation}"],
        ["{opNameUpper}: extract evaders - {region}.",
         "{articleOpforRoleCap} patrols are sweeping near {region}. Area is {distancePhrase}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}. {weatherPhrase}."]
    ]],
    ["TroopInsert", [
        ["{opNameUpper} - insertion near {region}.",
         "{factionFriendly} {bluforRole} is tasked to insert troops near {region} (grid {grid}). {instigatorCap}.",
         "Complete the insertion {timeHook}; {weatherPhrase} during {timePhase}."],
        ["{opNameUpper}: heliborne insert - {region}.",
         "Assault force lift to LZ near {region}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}."]
    ]],
    ["TroopExtract", [
        ["{opNameUpper} - extraction near {region}.",
         "Ground team needs pickup near {region} (grid {grid}). {instigatorCap}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}; {weatherPhrase}."],
        ["{opNameUpper}: troop extract - {region}.",
         "Extraction LZ is near {region}. {civSituation} Threat assessed at {echelon}.",
         "Recover all personnel {timeHook} during {timePhase}."]
    ]],
    ["Cargo", [
        ["{opNameUpper} - resupply near {region}.",
         "{factionFriendly} {bluforRole} will deliver cargo near {region} (grid {grid}). {instigatorCap}.",
         "This is a logistics run, not a deliberate fight; {stakes} {timeHook}."],
        ["{opNameUpper}: logistics run - {region}.",
         "Priority resupply to receiving party near {region}. {weatherPhrase}.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook} during {timePhase}."]
    ]],
    ["CASEVAC", [
        ["{opNameUpper} - CASEVAC near {region}.",
         "Casualty evacuation required near {region} (grid {grid}). {instigatorCap}.",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}; {civSituation}"],
        ["{opNameUpper}: medical evacuation - {region}.",
         "Wounded need aeromedical evacuation near {region}. Threat at {echelon}.",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook}; {weatherPhrase}."]
    ]],
    ["MineClearing", [
        ["{opNameUpper} - route clearance near {region}.",
         "{articleOpforRoleCap} {instigator} near {region} (grid {grid}).",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}; treat the route as contested until cleared."],
        ["{opNameUpper}: breach lane - {region}.",
         "Suspected hazard area near {region}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["GeoGuesser", [
        ["TRAINING - {opNameUpper} near {region}.",
         "{factionFriendly} {bluforRole} {instigator} near {region} (grid {grid}). No live enemy task-organised.",
         "Complete the training objective {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: map recon exercise - {region}.",
         "Non-combat familiarisation near {region}. {civSituation}",
         "{factionFriendly} {bluforRole} will {stakes} {timeHook} during {timePhase}."]
    ]],
    ["_default", [
        ["{opNameUpper} - tasking near {region}.",
         "{articleOpforRoleCap} activity is reported near {region} (grid {grid}). Estimated {echelon}. {civSituation}",
         "{factionFriendly} {bluforRole} must {stakes} {timeHook}. {weatherPhrase}."],
        ["{opNameUpper}: mission near {region}.",
         "Command tasks {factionFriendly} {bluforRole} near {region}. Area is {distancePhrase}.",
         "Priority is to {stakes} {timeHook} during {timePhase}."]
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
        case "Overcast": { "Overcast may cut long-range observation" };
        case "Foggy": { "Fog cuts visibility and slows movement" };
        case "Rain": { "Rain may degrade flying and sensors" };
        case "Storm": { "Storms may shrink the window for helicopters" };
        case "FaceMission": { "Weather matches the Face mission profile" };
        default { "Current weather is workable" };
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
        "Civilian presence is not expected in the objective area."
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
        "Sparse civilian activity expected; confirm IDs before shooting."
    };
    private _lt = _nearestMeta getOrDefault ["locType", ""];
    switch (_lt) do {
        case "NameCityCapital";
        case "NameCity": { format ["Dense civilian area around %1; watch your fires.", _region] };
        case "NameVillage": { format ["Village traffic near %1; locals may watch you work.", _region] };
        default { "Civilians may be present; confirm IDs." };
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
    private _colonLead = _uncertainty select [count _uncertainty - 1, 1] == ":";
    private _joiner = if (_colonLead) then { " " } else { " that " };
    private _line = if (_instigator != "") then {
        format ["%1%2%3 is reported to have %4 near %5", _uncertainty, _joiner, _enemy, _instigator, _region]
    } else {
        format ["%1%2%3 %4 is active near %5", _uncertainty, _joiner, _enemy, _articleRole, _region]
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
