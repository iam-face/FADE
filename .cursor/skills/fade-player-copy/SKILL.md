---
name: fade-player-copy
version: 1.0.0
description: |
  Apply the Humanizer skill to FADE player-facing copy (GUI blurbs, briefs,
  diary, lore pools, welcome hints, civ talk). Use when writing or editing any
  text players see in the FADE scenario sandbox. Follows milsim / CTB voice
  constraints and a priority file list.
license: MIT
compatibility: cursor
---

# FADE player-facing copy (Humanizer + milsim voice)

When editing text that players read in FADE, load and follow
[`.cursor/skills/humanizer/SKILL.md`](../humanizer/SKILL.md) (Humanizer 2.8.x),
then apply the FADE constraints below.

Humanizer removes AI writing tells. This skill tells you **which strings matter**,
**what voice to match**, and **what not to bleach**.

## Scope — treat as front-end copy

| Priority | Location | What players see |
|----------|----------|------------------|
| 1 | `rsc/MissionLore.sqf` | Procedural intro / SMEAC BACKGROUND / Intel “Background” |
| 2 | `rsc/MissionsGui.sqf` | Mission type one-liners, default desc, [G] / [S] rules |
| 3 | `rsc/Briefing.sqf` | Map Diary (Overview, Missions, Base, Scenario) + soft-spoken FADE Notes |
| 4 | `initPlayerLocal.sqf` | Welcome hint |
| 5 | `mission.sqm` ScenarioData / `description.ext` `overviewText` | Server browser / lobby overview |
| 6 | `rsc/ConfigDefaults.sqf` civ talk / rumour pools | Civilian dialogue replies |
| 7 | `rsc/FADE_MissionCommon.sqf` SMEAC fallbacks | Generic BACKGROUND when lore fails |
| 8 | `rsc/missions/*.sqf` + `FADE_*Client*.sqf` | Per-run briefs, task titles/descs, hints |

Also: GUI help paragraphs in `ScenarioGui.sqf`, `description.ext` dialog strings that are instructional prose (not one-word button labels).

## Out of scope / leave alone unless asked

- **Functional chrome:** button labels, tab names, lobby param titles, marker type names.
- **Doctrine reference** that is already dry and correct (CFF format, CAS 5-line, RATEL Over/Out, KAT bleeding tiers): fix only promotional filler, not procedure.
- **Community humour:** MOTD board jokes (`FADE_MOTDBoard.sqf`), OperationNames toilet adjectives, “Do not take SDE's STANAGs”, named rooms (Rhodesy / MB / SDE / etc.).
- **Debug / RPT / systemChat deny strings** meant for admins or error paths (keep short and literal).
- **Cutscenes:** no narrative captions today.

## Voice calibration (FADE)

Target register: **short OPORD / unit SOP**, mixed with CTB base flavour. Not a Steam store page. Not a LinkedIn post. Not “All-source assessment:” mad-libs unless the fill words are concrete.

**Match this feel:**

- Mission GUI one-liners that already work: *“Provide close air or indirect fires to support friendly forces under attack.”*
- Task briefs with grid + verb: *“Locate and neutralise or capture… Secure the area…”*
- Community specifics kept intact: Rhodesy’s office, MB’s gear room, SDE’s pub.

**Reject this feel (Humanizer patterns #1, #4, #7, #8, #27, #28 especially):**

- “high-value enablers that carry significant responsibility”
- “supports a positive and coherent experience for ground forces and other players”
- “threatens stability” / “prevent further escalation” / “local support erodes” as empty stakes
- brochure lists: “Explore the base… over 16 missions supported out of the box”
- Uniform “Expect X. Plan Y.” cadence across every MissionsGui row

**Do not** inject blog personality (§ PERSONALITY AND SOUL in Humanizer) into SMEAC, Intel, or doctrine notes. Neutral and plain *is* the correct human voice here. Personality belongs only in MOTD / pub jokes already present.

## How to run a copy pass

1. **Inventory** the strings you will touch (file + variable / array key). Prefer editing **pools and templates** in `MissionLore.sqf` over one-off mission scripts when the same phrase regenerates everywhere.
2. **Humanize** with draft → “still AI?” audit → final (Humanizer Process and Output). Strip em/en dashes from player prose; this repo already prefers ` - ` ASCII separators in many strings — keep that convention.
3. **Preserve slots** in lore templates: `{opNameUpper}`, `{region}`, `{grid}`, `{stakes}`, `{timeHook}`, `{factionFriendly}`, HTML `<font>` / `<br/>` markup, and `[G]` / `[S]` tags.
4. Prefer **concrete military verbs** (seize, clear, extract, hold, destroy) over abstract nouns (stability, freedom of movement, escalation).
5. After edits, grep for leftover AI vocabulary from Humanizer §7 in the touched files.
6. Do not change gameplay numbers, win conditions, or marker IDs while “just” editing copy.

## Worked targets (examples — apply when doing the pass)

### Rotary Piloting note (`Briefing.sqf`)

Before (significance + promotional):

> Rotary-wing assets are high-value enablers that carry significant responsibility. … supports a positive and coherent experience for ground forces and other players.

After (plain SOP):

> Rotary aircraft change the fight quickly and kill people when flown poorly. Treat the seat as earned: practice outside the mission so in-session flying is predictable for the ground force. The list below is the minimum bar.

### Lore stakes (`MissionLore.sqf` bundles)

Before: `"before local support erodes"` / `"prevent further escalation"` / `"deny the enemy freedom of movement"`

After: `"before they dig in"` / `"before they push further"` / `"before they move freely on that road"`

### Lobby overview (`mission.sqm` / diary Overview)

Before: feature catalogue with “Explore the base… over 16 missions…”

After: one short what / who / where sentence, then where to click (Rhodesy’s office → Manage Scenario / Missions). Detail stays in Diary sections, not the first screen.

## When to invoke

- User asks to improve blurbs, briefs, lore, diary, welcome text, or “make it sound less AI”.
- Agent is about to **add** a new mission type blurb, lore bundle, or diary paragraph — write it Humanizer-clean the first time.
- Soft trigger: editing any file in the Scope table above for string content.

## Related

- Upstream skill: [blader/humanizer](https://github.com/blader/humanizer) (MIT) — vendored at `.cursor/skills/humanizer/`.
- Display names only: `rsc/FAC_MissionTypeLabels.sqf` (keep in sync with MissionsGui ids, not prose).
