class RscDisplayBuild: FAC_Terminal {
    idd = 60950;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_buildGui_fnc', {}]); };";
};
