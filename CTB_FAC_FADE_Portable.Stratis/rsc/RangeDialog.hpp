class RscDisplayRange: FAC_Terminal {
    idd = 60920;
    onLoad = "0 spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_rangeGui_fnc', {}]); };";
};
