# YouTube Player Music — mod analysis for FADE

**Workshop:** [3683168022](https://steamcommunity.com/sharedfiles/filedetails/?id=3683168022)  
**Local install (this machine):** `D:\SteamLibrary\steamapps\workshop\content\107410\3683168022\`

## Package layout

| Path | Role |
|------|------|
| `youtube_player_music.pbo` | SQF, config, Zeus module UI (`a3yt_player` prefix) |
| `youtube_player_music_x64.dll` | **Required** native extension (~6.5 MB) |
| `youtube_player_music.dll` | 32-bit extension |
| `Key\Alpha.bikey` | Addon signature |

PBO contents (from binary inspection; extractor did not unpack — PBO uses version header):

- `config.cpp` — patches, Zeus attributes UI (`A3YT_RscAttributeYoutube`), module `A3YT_ModuleYoutubeAudio`
- `functions\fn_*.sqf` — see function list below
- `Stringtable.xml` — UI strings (`STR_A3YT_*`)

### Compiled functions (`A3YT_fnc_*`)

| Function | Purpose |
|----------|---------|
| `fn_callExtension` | Wrapper around `callExtension "youtube_player_music"` |
| `fn_moduleYoutube` | Zeus/Curator global playlist module |
| `fn_modulePropAudio` | Prop / object-attached playback module |
| `fn_handleLocalPlayback` | Client global queue worker |
| `fn_handleLocalPropPlayback` | Client 3D prop playback (radius, attenuation) |
| `fn_uiModuleYoutube` | Zeus attribute dialog handlers |
| `fn_forceStopLocalPropPlayback` | Stop prop source |
| `fn_*Volume*` | Client volume override / pause-menu UI |

### Extension commands (via `A3YT_fnc_callExtension`)

Observed command names: `play`, `stop`, `pause`, `resume`, `volume`, `seek`, `prefetch`, `preview`, `title`, `timeline`, `playlistload`, `playlistitem`, `status`, `notify`, `warmup`, `update`, `dispatch`, `refreshVolume`, plus `Radius` / `Attenuation` / `Volume` / `Url` / `Action` / `Queue` parameter keys.

Prop playback uses missionNamespace state including:

- `A3YT_localPropNetId` — emitter object netId
- `A3YT_localPropUrl` — YouTube URL
- `A3YT_localPropBaseVolume`, `A3YT_localPropRadius` (default **25** m in snippets)
- `A3YT_localPropLoop`, `A3YT_localPropAttenuation`

Global playlist uses `A3YT_localQueue`, `A3YT_localQueueVolume`, etc.

## Can we embed this in the mission (no separate mod subscribe)?

**No — not in a working form.**

1. **Native DLL** — YouTube audio is decoded/streamed through `youtube_player_music_x64.dll`. Arma missions cannot load custom extensions; players must load the mod (or a repackaged addon folder) so the DLL sits beside the PBO.
2. **BattlEye** — As of Mar 2026 the author reports **BattlEye whitelist blocks custom DLLs**. Usable only with BE disabled or if/when Bohemia whitelists the extension. FADE public servers likely need BE on → treat as **blocked until whitelisted**.
3. **CBA dependency** — `config.cpp` lists `requiredAddons[] = {"A3_Modules_F", "cba_ui"}`. FADE already uses CBA in many environments, but the mod is not “SQF-only”.
4. **License / repack** — `mod.cpp` asks the mod stay a **standalone, unmodified** Workshop item in presets (no bundling into another PBO). Practical approach: **server modline + optional client preset**, not mission-embedded copy.

Copying only the SQF into `rsc/` would compile but **every `callExtension` would fail** without the DLL.

## Recommended FADE integration (next phase)

### Server / preset

- Add **YouTube Player Music** to the CTB/FADE mod preset (Workshop `3683168022`).
- Document BE requirement (or “training server only” until whitelist).
- Keep lobby **ACCESS: Base music** (`FAC_param_baseMusicAccess`) gating who may open the UI.

### Per-source 3D at base (`Radio_1`–`Radio_4`)

The old jukebox used `radio:Radio_N` source keys and `playSound3D` from each client. The YouTube mod’s **prop playback** path is the closest match:

1. On `addAction` at each `Radio_*`, open a FADE wrapper dialog (or call into mod UI) to paste a YouTube URL.
2. Server validates access + source id; `remoteExec` to all clients with `[url, netId Radio_N, volume, radius]`.
3. Each client calls mod API (e.g. set `A3YT_localProp*` vars + `A3YT_fnc_handleLocalPropPlayback`) **if** `isClass (configFile >> "CfgPatches" >> "A3YT_player")`.
4. Stop / admin “stop all music” → `A3YT_fnc_forceStopLocalPropPlayback` per source or global stop.

**Alternative:** Place invisible `A3YT_ModuleYoutubeAudio` modules in Eden per radio (author’s Zeus workflow) — less ideal for player-facing base laptops.

### Vehicle loudspeaker

Old jukebox supported `vehicle:<netId>` crew-only loudspeaker. The mod’s global queue is not per-vehicle; prop playback on the vehicle netId may work similarly — needs in-game test.

### Civ ambient car radio

Was tied to jukebox `FAC_jukebox_serverPlay`. Either drop, or later use prop playback on civ vehicle netId with a static URL list (not YouTube-friendly for random traffic).

## Extraction note

`tools/pbo_extract.py` returned 0 files (PBO uses `sreV` version block). Use **Mikero DePbo / Eliteness / Arma 3 Tools** to fully unpack `youtube_player_music.pbo` for line-accurate SQF when implementing the wrapper.
