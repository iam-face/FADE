// Scenario admin dialog (included from description.ext)
class RscDisplayScenarioAdmin: RscDisplayEmpty {
    idd = 60004;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoadAdmin', []] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.22; y = 0.12; w = 0.56; h = 0.76; colorBackground[] = {0.1, 0.1, 0.15, 0.95}; };
        class Title: RscText { idc = -1; text = "SCENARIO - ADMIN OPTIONS"; x = 0.22; y = 0.12; w = 0.56; h = 0.05; colorBackground[] = {0.2, 0.4, 0.6, 1}; colorText[] = {1, 1, 1, 1}; sizeEx = 0.042; };
    };
    class controls {
        class HeaderRefreshBtn: RscButton { idc = 60439; text = "Refresh"; x = 0.66; y = 0.125; w = 0.065; h = 0.042; sizeEx = 0.026; colorBackground[] = {0.18, 0.32, 0.48, 1}; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class HeaderCloseBtn: RscButton { idc = 60440; text = "X"; x = 0.735; y = 0.125; w = 0.045; h = 0.042; sizeEx = 0.032; colorBackground[] = {0.35, 0.22, 0.22, 1}; action = "closeDialog 0;"; };
        class MakeZeusBtn: RscButton { idc = 60435; text = "Make me Zeus"; x = 0.27; y = 0.19; w = 0.46; h = 0.052; sizeEx = 0.032; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['adminCleanup', ['makeZeus']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class RemoveZeusBtn: RscButton { idc = 60436; text = "Remove my Zeus"; x = 0.27; y = 0.252; w = 0.46; h = 0.052; sizeEx = 0.032; colorBackground[] = {0.25, 0.22, 0.22, 1}; action = "['adminCleanup', ['removeMyZeus']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class TeleportAllBaseBtn: RscButton { idc = 60437; text = "Teleport all players to HQ (teleportBase)"; x = 0.27; y = 0.314; w = 0.46; h = 0.052; sizeEx = 0.028; colorBackground[] = {0.2, 0.4, 0.62, 1}; action = "['adminCleanup', ['teleportAllToBase']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class StopAllMusicBtn: RscButton { idc = 60438; text = "Stop all music (jukebox)"; x = 0.27; y = 0.376; w = 0.46; h = 0.052; sizeEx = 0.028; colorBackground[] = {0.22, 0.35, 0.28, 1}; action = "['adminCleanup', ['stopAllMusic']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class AbortAllBtn: RscButton { idc = 60430; text = "Abort all missions"; x = 0.27; y = 0.438; w = 0.46; h = 0.052; sizeEx = 0.032; action = "['adminCleanup', ['abortAllMissions']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class DespawnCivBtn: RscButton { idc = 60431; text = "Despawn civilians"; x = 0.27; y = 0.500; w = 0.46; h = 0.052; sizeEx = 0.032; action = "['adminCleanup', ['despawnCivilians']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class DespawnOpforBtn: RscButton { idc = 60432; text = "Despawn OPFOR"; x = 0.27; y = 0.562; w = 0.46; h = 0.052; sizeEx = 0.032; action = "['adminCleanup', ['despawnOpfor']] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]);"; };
        class BackBtn: RscButton { idc = 60433; text = "Back"; x = 0.27; y = 0.634; w = 0.46; h = 0.055; sizeEx = 0.034; action = "closeDialog 0; [] spawn { sleep 0.05; ['open', []] call (missionNamespace getVariable ['FAC_scenarioGui_fnc', {}]); };"; };
    };
};
