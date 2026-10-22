class RscDisplaySniper: FAC_Terminal {
    idd = 60910;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_sniperGui_fnc', {}]); };";
};
