class RscDisplayLoadout: FAC_Terminal {
    idd = 60200;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_loadoutGui_fnc', {}]); };";
};
