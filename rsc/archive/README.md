# Archived mission scripts

Files here are **not compiled, execVM'd, or #included** by the live mission. Kept for reference or optional restore.

| File | Reason archived |
|------|-----------------|
| `FiresDroneVideoFeed_archived.sqf` | Briefing-screen drone RTT removed from `FiresFallOfShot.sqf`; observer UAV + terminal unchanged |
| `CivTalkDialog_vertical.hpp` | Optional vertical CivTalk layout; runtime uses `CivTalkGui.sqf` + `CivTalkDialog.hpp` |
| `MissionsMapClickAnchor_archived.sqf` | Empty placeholder; map-click lives in `FADE_MapClickPick.sqf` / `MissionMapPick.sqf` |
| `JukeboxGui_archived.sqf`, `JukeboxDialog_archived.hpp`, `JukeboxVehicleSFX_archived.hpp`, `FAC_CivCarRadioTracks_archived.sqf`, `laptopJukebox.jpg` | Sig/CTB loudspeaker jukebox removed 2026-07-09; see **`Jukebox_README.md`** |
| `YOUTUBE_PLAYER_MUSIC_ANALYSIS.md` | Workshop mod 3683168022 — integration constraints and plan |

To restore something, move it back under `rsc/` and wire it into the appropriate boot path (`initServer`, `FAC_ClientGuiEnsure`, or `description.ext`).
