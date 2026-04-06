// Jukebox dialog -- tracks + volume (1–25) / audible distance (50–2500 m) for playSound3D (see rsc\JukeboxGui.sqf)
// Included from description.ext — sliders match track list width (0.46).
class RscDisplayJukebox: RscDisplayEmpty {
    idd = 60400;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]); };";
    class controlsBackground {
        class Background: RscText { idc = -1; x = 0.25; y = 0.08; w = 0.50; h = 0.84; colorBackground[] = {0.1, 0.1, 0.15, 0.95}; };
        class Title: RscText { idc = -1; text = "JUKEBOX"; x = 0.25; y = 0.08; w = 0.50; h = 0.05; colorBackground[] = {0.2, 0.4, 0.6, 1}; colorText[] = {1, 1, 1, 1}; sizeEx = 0.05; };
    };
    class controls {
        class HeaderRefreshBtn: RscButton { idc = 60408; text = "Refresh"; x = 0.62; y = 0.082; w = 0.08; h = 0.044; sizeEx = 0.028; colorBackground[] = {0.18, 0.32, 0.48, 1}; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class HeaderCloseBtn: RscButton { idc = 60409; text = "X"; x = 0.71; y = 0.082; w = 0.048; h = 0.044; sizeEx = 0.034; colorBackground[] = {0.35, 0.22, 0.22, 1}; action = "closeDialog 0;"; };
        class SearchLabel: RscText { idc = -1; text = "Search:"; x = 0.27; y = 0.14; w = 0.08; h = 0.03; sizeEx = 0.032; };
        class SearchEdit: RscEdit { idc = 60401; x = 0.35; y = 0.14; w = 0.38; h = 0.04; sizeEx = 0.032; onKeyUp = "['filter', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class SongListLabel: RscText { idc = -1; text = "Tracks:"; x = 0.27; y = 0.19; w = 0.20; h = 0.03; sizeEx = 0.032; };
        class SongList: RscListBox { idc = 60402; x = 0.27; y = 0.22; w = 0.46; h = 0.435; rowHeight = 0.038; sizeEx = 0.033; onLBSelChanged = "['updateButtons', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class VolumeLabel: RscText { idc = -1; text = "Volume (1–25):"; x = 0.27; y = 0.663; w = 0.46; h = 0.022; sizeEx = 0.026; colorText[] = {0.92, 0.92, 0.92, 1}; };
        class VolumeSlider: RscXSliderH { idc = 60411; x = 0.27; y = 0.685; w = 0.46; h = 0.026; onSliderPosChanged = "['volumeSliderChanged', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class VolumeValue: RscText { idc = 60412; style = 1; text = "4"; x = 0.27; y = 0.711; w = 0.46; h = 0.020; sizeEx = 0.024; colorText[] = {0.85, 0.95, 1, 1}; };
        class DistanceLabel: RscText { idc = -1; text = "Audible distance (m):"; x = 0.27; y = 0.733; w = 0.46; h = 0.022; sizeEx = 0.026; colorText[] = {0.92, 0.92, 0.92, 1}; };
        class DistanceSlider: RscXSliderH { idc = 60414; x = 0.27; y = 0.755; w = 0.46; h = 0.026; onSliderPosChanged = "['distanceSliderChanged', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class DistanceValue: RscText { idc = 60415; style = 1; text = "400"; x = 0.27; y = 0.781; w = 0.46; h = 0.020; sizeEx = 0.024; colorText[] = {0.85, 0.95, 1, 1}; };
        class NowPlayingLabel: RscText { idc = -1; text = "Now playing:"; x = 0.27; y = 0.807; w = 0.13; h = 0.028; sizeEx = 0.030; };
        class NowPlayingText: RscText { idc = 60403; text = "-- Nothing --"; x = 0.40; y = 0.807; w = 0.33; h = 0.028; sizeEx = 0.030; colorText[] = {0.5, 1.0, 0.5, 1}; };
        class PlayBtn: RscButton { idc = 60404; text = "PLAY"; x = 0.27; y = 0.847; w = 0.22; h = 0.04; sizeEx = 0.035; action = "['play', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class StopBtn: RscButton { idc = 60405; text = "STOP"; x = 0.51; y = 0.847; w = 0.22; h = 0.04; sizeEx = 0.035; action = "['stop', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
    };
};
