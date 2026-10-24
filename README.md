![](CTB_FAC_FADE.Altis/img/gh-logo.jpg)

# FADE (Face's Dynamic Environment)

FADE is a multiplayer Arma 3 sandbox built for [Combat Team Bravo](https://discord.gg/d5g2dFH). From base you set the theatre, then start a generated mission or use a training range. A normal session runs from the boards and GUIs. Zeus is optional. Forks and pull requests of this repo are welcome.

[YouTube](https://www.youtube.com/@iamface) · [CTB Discord](https://discord.gg/d5g2dFH)

![CTB Flag](./CTB_FAC_FADE.Altis/img/flagCTB.jpg)

## Combat Team Bravo

CTB is an Australian Arma group with more than 17 years of story-driven milsim. We play Sunday and Monday nights at 1930 AEST. Sunday is training and mini-ops. Monday is the main op.

The style is approachable milsim: tactics and immersion, with room for banter. There are no ranks, no fixed roles, and no attendance minimum. Real life comes first, so mark your RSVP when you can make it. Players are 18+. Ops regularly use Apex, Contact, SOG, Global Mobilization, and Spearhead 1944.

## Maps

`CTB_FAC_FADE.Altis` is the main CTB Altis mission, with a pre-built base. `CTB_FAC_FADE_Portable.Stratis` is the portable template, on Stratis. On the portable variant, a logged-in admin places the player base, or players vote for it to be placed at a location of their choosing. 

The server holds up to 31 players. It owns the scenario, the AI, and mission spawns. Clients open the GUIs and receive updates over `remoteExec` and public variables. Lobby parameters in `description.ext` set who can open each GUI, and the starting weather, OPFOR, civilians, and build rules.

## A typical session

Open **Manage Scenario** at the mission board, or via ACE self-interact. Set weather, time, factions, civilians, gear, and how hard OPFOR fights. Apply sends that to the server, including players who join later. Admins and Zeus can override group-leader locks on the GUIs.

Open **Manage Missions**, or press `Ctrl+;`. Pick a type, read the blurb, and start. Some types ask for a map click or a player first. The blurb states the objective and the win condition.

Around the base you can place vehicles, apply loadouts, recruit friendly AI, and fast travel (`Ctrl+Shift+'`). The Altis FADE variant includes a CQB shoothouse, ACE and KAT medical dummies, rifle, AT, and sniper ranges, and a FIRES terminal for call-for-fire practice with fall-of-shot screens. HQ auto-heal is on unless the lobby turns it off.

Within 1000 m of the Altis base (500 m on the portable variant), ACE self-interact repeats those actions and adds **Build**. Place opens a camera. Space drops the piece. Esc leaves the camera. Ctrl+Z removes the last piece you placed, and the Placed tab can delete any of them. Look at a placed object, then ACE Interact and Destroy, to take it down. On a piece that already has a texture, Write sets the sign text. Type `\n` for a new line.

By default anyone can build, anywhere, from the realistic list: fortifications, camp gear, and supplies. An admin can switch that list to allow players to build every prop in the game. An optional shared supply pool, and an optional rule that Gear, Barracks, Vehicles, and Medical tents must be placed before those services work, stay off unless the lobby turns them on. Outside the bubble, **Build** appears on ACE self-interact by itself when the lobby allows building anywhere. The rest of the FADE menu stays at base.

Vehicle placement uses the same camera, inside the same bubble. Search and a faction filter narrow the list. Spawned vehicles can be repaired, rearmed, refuelled, and given pylons when the vehicle has them.

## Missions

One **global** mission runs for the whole server. Each player can also hold up to three **single** missions.

Global missions include Area of Operations, Asset Retrieval, CAS / Fire Support, Clear Area, CSAR, Escape and Evasion, Geo-Guesser, Hostage, HVT, Intercept Convoy, Invasion, Point Defense, Operation, Raid, and Search and Destroy. 

Single missions are Troop Insert, Troop Extract, Cargo / Resupply, CASEVAC, and Mine Clearing.

HVT, Hostage, Search and Destroy, and Asset Retrieval use a 100 m search grid. Searching a dead enemy for field intel tightens the zone. The marked area still contains every objective. Raid uses the same grids and reveals the target when friendlies close in, or when the garrison is in contact. Cargo camps, Clear Area camps, and two Area of Operations objectives share one prop set: a three-tent camp, a mortar pit, or a comms relay.

Most objectives get up to four OPFOR checkpoints on nearby roads. One faces the base. They stay when patrols are off, and they leave when the mission ends. Empty unarmored trucks park near town objectives. A truck a player has taken stays taken. Ambient town blocks and corridor blocks still need patrols on.

Civilians walk towns drawn from the map. Talk to them for tips, and search buildings for intel. Lobby settings choose who may do each. A started mission gets a procedural name and a SMEAC-style brief. The map diary holds scenario notes and a joint-fires reference. MOTD boards rotate short messages, and the HQ board shows the current op name.

## The enemy and the kit

Faction lists come from `CfgFactionClasses`, limited to factions the server can spawn infantry for. Friendly covers EAST, WEST, and GUER. Enemy is limited to sides opposed to the players. GUER counts as hostile to both major sides. The start mix is RHS US Army (desert, then woodland), RHS Russia (MSV), and CDF ground forces when those mods are loaded. Otherwise it is NATO, CSAT, and AAF. Civilians stay the vanilla civilian faction. Apply rejects a faction with no infantry and keeps the previous one. Invalid mixes are corrected on Apply, with a hint. Player side updates on Apply, on join, and on respawn.

OPFOR population, patrols (including a chance they sit in towns), skill, retreat, AAA, grenades, air, and drones are Scenario and lobby settings. Grenades default to Reduced, which caps thrown HE, under-barrel HE, and dedicated grenade launchers. Smoke, flares, and chemlights stay. Scaling garrison, patrol, and QRF size with the number of living players is off unless you turn it on. Population alone still sets the counts. Air and drones default to off. A sensor inside an objective can start that mission's quick reaction force. Knocked-out AI soldiers die while Prohibit AI unconscious is on. That is the default. Players, civilians, medical dummies, and CASEVAC or CSAR casualties can still be unconscious. The lobby and the Scenario Admin tab both set the rule.

Gear policy is Unrestricted, friendly faction only, or preset loadouts only. ACE Arsenal on the loadout boxes is on by default. Recruit access is everyone, group leaders, or admin. It spawns friendly AI from faction infantry or custom presets, assigns them to a friendly group, and dismisses them from the Roster tab.

## Mods

`mission.sqm` references several mods and DLCs. Spawnable equipment is read from the running Arma config, so much of the sandbox still runs without the full set. Loadouts and the Altis base layout need the CTB modlist. Get that list from the CTB Discord.

If you want to produce a modless variant of FADE, simply load the scenario in your editor with no mods running, force-load, and re-save it. The scenario will still function.

## Still in progress

The backlog and design notes are in [TODO.md](TODO.md).

- Replace Operation with an intel-gated 3 by 3 km grid and three hidden objectives. Standalone Hunt is not planned.
- Add engine radio voice (`kbTell`) on top of the existing side-chat subtitles.

## For contributors

Entry points are `initServer.sqf`, which loads `rsc/server/`, and `initPlayerLocal.sqf`. Per-type runners live in `rsc/missions/`. `rsc/Missions.sqf` dispatches them. `FADE_*` is server, world, and mission logic. `FAC_*` is client GUI, theme, and lobby parameters. `.cursor/` and `.vscode/` are local editor files and are gitignored.

The debug-tools lobby parameter adds two scroll-wheel actions.

`[] call FAC_missionTestSuite_execAll` checks compile, RPCs, placement, SMEAC and intel text, zone pickers, and the client GUI scripts. Filter the RPT on `[FAC TestSuite]`. It does not play a mission through.

`[] call FAC_playthroughSuite_execAll` runs the mission types in about 10 minutes or less, with no player input after you start it. The server teleports and applies win cheats. Filter on `[FAC Playthrough]`. Abort with `[] call FAC_playthroughSuite_abort`. Budgets and phase toggles are in `rsc/MissionPlaythroughProfiles.sqf`.

Offline lint, from a mission folder, after you install the [SQF-VM Language Server](https://marketplace.visualstudio.com/items?itemName=SQF-VM.sqf-vm-language-server):

```
powershell -ExecutionPolicy Bypass -File ..\..\tools\sqfvm\Invoke-FadeSqfLint.ps1 -InstallIfMissing
```

That pass is static analysis. It does not prove the mission runs.

Headless dedicated tests:

```
powershell -ExecutionPolicy Bypass -File ..\..\tools\headless\Run-FadeHeadlessTest.ps1
```

Modes are `-Mode boot`, `-Mode compile` (the default), `-Mode playthrough`, and `-Mode all`. Local config is `..\..\tools\headless\headless.local.json`.
