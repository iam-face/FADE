class RscDisplayRecruit: FAC_Terminal {
    idd = 60940;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_recruitGui_fnc', {}]); };";
};
