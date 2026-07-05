// Jukebox dialog — compact centered panel with FADE chrome
class RscDisplayJukebox: RscDisplayEmpty {
    idd = 60400;
    movingEnable = 1;
    enableSimulation = 1;
    onLoad = "[] spawn { sleep 0.01; ['onLoad', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]); };";
    class controlsBackground {
        class Background: FACRscDialogBackground { x = 0.25; y = 0.08; w = 0.50; h = 0.84; };
        class HeaderBar: FACRscHeaderBar { x = 0.25; y = 0.08; w = 0.50; h = 0.065; };
    };
    class controls {
        class TitleText: FACRscDialogTitle { text = "JUKEBOX"; x = 0.27; y = 0.086; w = 0.30; h = 0.052; sizeEx = 0.034; };
        class HeaderRefreshBtn: FACRscRefreshBtn { idc = 60408; x = 0.62; y = 0.086; w = 0.08; h = 0.044; action = "['headerRefresh', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class HeaderCloseBtn: FACRscCloseBtn { idc = 60409; x = 0.71; y = 0.086; w = 0.048; h = 0.044; };
        class SearchLabel: FACRscLabelMuted { idc = -1; text = "Search"; x = 0.27; y = 0.16; w = 0.10; h = 0.028; sizeEx = 0.028; };
        class SearchEdit: FACRscEditDark { idc = 60401; x = 0.35; y = 0.158; w = 0.38; h = 0.036; sizeEx = 0.028; onKeyUp = "['filter', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class SongListLabel: FACRscLabelMuted { idc = -1; text = "Tracks"; x = 0.27; y = 0.20; w = 0.20; h = 0.028; sizeEx = 0.028; };
        class SongList: FACRscListDark { idc = 60402; x = 0.27; y = 0.23; w = 0.46; h = 0.42; rowHeight = 0.036; sizeEx = 0.030; onLBSelChanged = "['updateButtons', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class VolumeLabel: FACRscLabelMuted { idc = -1; text = "Volume (1–25)"; x = 0.27; y = 0.66; w = 0.46; h = 0.022; sizeEx = 0.024; };
        class VolumeSlider: RscXSliderH { idc = 60411; x = 0.27; y = 0.682; w = 0.46; h = 0.026; onSliderPosChanged = "['volumeSliderChanged', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class VolumeValue: RscText { idc = 60412; style = 1; text = "4"; x = 0.27; y = 0.708; w = 0.46; h = 0.020; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class DistanceLabel: FACRscLabelMuted { idc = -1; text = "Audible distance (m)"; x = 0.27; y = 0.73; w = 0.46; h = 0.022; sizeEx = 0.024; };
        class DistanceSlider: RscXSliderH { idc = 60414; x = 0.27; y = 0.752; w = 0.46; h = 0.026; onSliderPosChanged = "['distanceSliderChanged', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class DistanceValue: RscText { idc = 60415; style = 1; text = "400"; x = 0.27; y = 0.778; w = 0.46; h = 0.020; sizeEx = 0.022; colorText[] = FAC_COLOR_TEXT_MUTED; };
        class NowPlayingLabel: FACRscLabelMuted { idc = -1; text = "Now playing"; x = 0.27; y = 0.802; w = 0.14; h = 0.026; sizeEx = 0.026; };
        class NowPlayingText: RscText { idc = 60403; text = "— Nothing —"; x = 0.40; y = 0.802; w = 0.33; h = 0.026; sizeEx = 0.026; colorText[] = FAC_COLOR_TEXT_OK; };
        class PlayBtn: FACRscPrimaryBtn { idc = 60404; text = "Play"; x = 0.27; y = 0.842; w = 0.22; h = 0.04; sizeEx = 0.030; action = "['play', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
        class StopBtn: RscButton { idc = 60405; text = "Stop"; x = 0.51; y = 0.842; w = 0.22; h = 0.04; sizeEx = 0.030; colorBackground[] = FAC_COLOR_BTN_NEUTRAL; colorText[] = FAC_COLOR_TEXT; action = "['stop', []] call (missionNamespace getVariable ['FAC_jukeboxGui_fnc', {}]);"; };
    };
};
