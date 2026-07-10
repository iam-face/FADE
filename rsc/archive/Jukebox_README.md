# Archived FADE jukebox (Sig / CTB loudspeaker)

Removed from the live mission **2026-07-09** during a brief YouTube Player Music experiment; **restored to live mission 2026-07-09** (same Sig/CTB jukebox as before).

## Archived files

| File | Was |
|------|-----|
| `JukeboxGui_archived.sqf` | Client GUI + 3D playback (`playSound3D` / `createSoundSource`) |
| `JukeboxDialog_archived.hpp` | `RscDisplayJukebox` (idd **60400**) |
| `JukeboxVehicleSFX_archived.hpp` | Mission `CfgSFX` mirrors for vehicle loudspeaker |
| `FAC_CivCarRadioTracks_archived.sqf` | Ambient civ car Sig_* track pool |
| `laptopJukebox.jpg` | Laptop texture on `Radio_*` / `musicBoard` |

See also **`YOUTUBE_PLAYER_MUSIC_ANALYSIS.md`** for the replacement mod and integration notes.

## How to restore the old jukebox

1. Move archived `.sqf` / `.hpp` / `.jpg` back under `rsc/` and `img/` (original names).
2. **`description.ext`**
   - Restore `#include "rsc\JukeboxDialog.hpp"`.
   - Restore `CfgSounds` Sig_* / `FAC_JukeVeh_*` entries, `CfgSFX` include, `FAC_FADE_JukeboxSounds` patch, and `CfgVehicles` `FAC_Jukebox_*` Sound subclasses (copy from git history or this archive’s companion commit).
   - Restore lobby param `FAC_JukeboxAccess` if renamed.
3. **`rsc/FAC_ClientGuiEnsure.sqf`** — restore `FAC_ensureJukeboxGui` and `FAC_jukebox_fnc_registerClientRpc`.
4. **`rsc/server/ServerServices.sqf`** — restore `FAC_jukebox_serverPlay` and helpers.
5. **`rsc/server/ServerGameplayMissionAdmin.sqf`** — restore `FAC_jukebox_stopAllMusic` and admin `stopAllMusic` action.
6. **`rsc/FAC_ClientBoardActions.sqf`** — restore `Radio_1`–`Radio_4` jukebox addAction and vehicle loudspeaker handlers.
7. **`initPlayerLocal.sqf`** / **`onPlayerRespawn.sqf`** — restore jukebox ensure / respawn hooks.
8. **`rsc/server/ServerBootstrap.sqf`** — restore `FADE_playerCanUseJukebox` alias.
9. **`rsc/MissionTestSuite.sqf`** — restore jukebox compile / Rsc / CfgVehicles tests.
10. **`rsc/AmbientCiviliansSpawn.sqf`** — restore civ car radio (`FAC_jukebox_serverPlay` path) and `FAC_CivCarRadioTracks.sqf` load.
11. Update **Briefing**, **README**, **AGENTS.md** (idd 60400) if needed.

Requires **`@CTB - Mission Sounds Library`** (`Sig_CTB_MSL_Music_Loudspeaker`) on server and clients for OGG playback.

## Eden objects (unchanged in mission.sqm)

- **`Radio_1` … `Radio_4`** — jukebox interaction points (live mission uses `FAC_ClientBoardActions`).
- **`musicBoard`** — decorative laptop next to radios.
