// =============================================================================
// FAC_MissionTypeLabels.sqf  -  display names for mission type IDs (server init)
// =============================================================================
// Keep [displayName, missionId] in sync with rsc/MissionsGui.sqf _missionListRaw
// columns [0] and [1]. Used for FADE_showMissionAssignedIntro subtitle (mission type).
// =============================================================================

missionNamespace setVariable ["FAC_missionTypeLabels", [
    ["Area of Operations", "AreaOfOperations"],
    ["Asset Retrieval", "AssetRetrieval"],
    ["CAS / Fire Support", "CAS"],
    ["Cargo / Resupply", "Cargo"],
    ["CASEVAC", "CASEVAC"],
    ["Clear Area", "ClearArea"],
    ["CSAR", "CSAR"],
    ["Escape & Evasion", "EscapeEvasion"],
    ["Geo-Guesser", "GeoGuesser"],
    ["Hostage", "Hostage"],
    ["HVT", "HVT"],
    ["Intercept Convoy", "InterceptConvoy"],
    ["Mine Clearing", "MineClearing"],
    ["Operation", "Operation"],
    ["Search & Destroy", "SearchDestroy"],
    ["Troop Extract", "TroopExtract"],
    ["Troop Insert", "TroopInsert"]
]];

missionNamespace setVariable ["FADE_missionTypeDisplayName", {
    params ["_id"];
    private _lbl = _id;
    { if ((_x select 1) == _id) exitWith { _lbl = _x select 0 } } forEach (missionNamespace getVariable ["FAC_missionTypeLabels", []]);
    _lbl
}];
