---
name: fade-player-copy
version: 2.0.0
description: |
  Optimise FADE player-facing copy into readable, consistent, military-style
  prose: short orders and unit SOP, one action per sentence, concrete verbs.
  Use when writing or editing text players see in the FADE scenario (GUI blurbs,
  briefs, diary, lore pools, welcome hints, civilian talk, task text), or when
  asked to optimise, humanize, de-slop, or simplify that copy. This skill owns
  that text. A generic humanizer, SlopMonster, or ASD-STE100 pass does not.
license: MIT
compatibility: cursor
---

# FADE player copy

Rewrite text a player reads so it is easy to act on. The register is a short order or unit SOP: the action or the fact first, one job per sentence, the same word for the same thing. Plain is the correct voice for orders, intel, and doctrine.

This file is the whole pass. Do not load Humanizer, SlopMonster, or `asd-ste100` unless the user names that skill. Those skills contributed the rules below. Their defaults fight this scenario: Humanizer will add blog voice, STE will force American spelling and ban unit terms, SlopMonster's checker scores SQF as if it were an essay.

## Who is reading

A player at the board, on the map, or in a hint. They need the task, the place, and the constraint. They already know this is a milsim. Do not teach the genre, sell the mission, or restate the screen they are looking at.

## Scope

| Priority | Location | What players see |
|----------|----------|------------------|
| 1 | `rsc/MissionLore.sqf` | Procedural intro / SMEAC BACKGROUND / Intel "Background" |
| 2 | `rsc/MissionsGui.sqf` | Mission type one-liners, default desc, [G] / [S] rules |
| 3 | `rsc/Briefing.sqf` | Map Diary (Overview, Missions, Base, Scenario) and FADE Notes |
| 4 | `initPlayerLocal.sqf` | Welcome hint |
| 5 | `mission.sqm` ScenarioData / `description.ext` `overviewText` | Server browser / lobby overview |
| 6 | `rsc/ConfigDefaults.sqf` civ talk / rumour pools | Civilian dialogue replies |
| 7 | `rsc/FADE_MissionCommon.sqf` SMEAC fallbacks | Generic BACKGROUND when lore fails |
| 8 | `rsc/missions/*.sqf` + `FADE_*Client*.sqf` | Per-run briefs, task titles and descriptions, hints |

Also in scope: GUI help paragraphs in `ScenarioGui.sqf`, and `description.ext` dialog strings that are instructional prose.

## Leave alone unless the user names them

- **Chrome:** button labels, tab names, lobby param titles, marker type names. Display names in `rsc/FAC_MissionTypeLabels.sqf` stay in sync with MissionsGui ids. They are names, not prose.
- **Doctrine that is already dry:** CFF format, CAS 5-line, RATEL Over/Out, KAT bleeding tiers. Cut promotional filler around the procedure. Do not paraphrase the procedure.
- **Community humour:** MOTD jokes (`FADE_MOTDBoard.sqf`), OperationNames toilet adjectives, "Do not take SDE's STANAGs", named rooms (Rhodesy's office, MB's gear room, SDE's pub).
- **Admin and error strings:** RPT and `systemChat` deny paths. Keep them short and literal.
- **Code:** class names, marker IDs, win conditions, gameplay numbers, `remoteExec`, string slots, HTML tags. A copy pass does not change how the mission runs.

## Pick a register first

Classify each string. Do not mix registers in one paragraph.

### Order or task

Mission GUI one-liners, task titles and descriptions, "how to" hints, execution lines.

- Imperative, or a direct instruction. One instruction per sentence. Two actions only when they happen at the same time.
- Put a condition before the order: "If the LZ is hot, hold east of the grid."
- Keep instructional sentences near 20 words. Split a longer one.
- Lead with the verb and the place when the source has a grid, building, or route.
- Lock the verb. Use seize, clear, extract, hold, destroy, locate, capture, mark, escort, recover, or the verb already in that mission. Do not rotate clear / secure / sanitise for one job.
- A warning names the act, then the result: "Do not overfly the town. Small arms reach the aircraft."

Match: "Provide close air or indirect fires to support friendly forces under attack."

### Intel or background

Lore pools, diary situation, SMEAC background.

- Facts only. One new fact per sentence. Keep descriptive sentences near 25 words.
- No orders inside the situation paragraph. The task line carries the order.
- A stake is a concrete enemy action already supported by the source: "before they dig in", "before they push further", "before they move freely on that road".
- Keep uncertainty only when the source is uncertain. Write the condition, or say what is not known. Do not stack hedges ("could potentially"). Do not promote a maybe into a fact.

### Base flavour

Civilian replies, and diary or welcome lines that are already in the unit's voice.

- Keep the joke, the name, and the attitude.
- Still cut brochure language and the tells below.
- Do not turn civilian talk into an OPORD.

## Spelling, slots, punctuation

- Keep this scenario's spelling: neutralise, defence, armour. Do not convert to American English.
- Keep callsigns, grids, faction names, `{opNameUpper}`, `{region}`, `{grid}`, `{stakes}`, `{timeHook}`, `{factionFriendly}`, HTML `<font>` / `<br/>`, and `[G]` / `[S]` tags.
- Player prose uses a period, comma, colon, or parentheses. No em dashes or en dashes. Where a file already uses an ASCII ` - ` separator, keep that separator.
- Keep articles. "Secure the area." Short is not a telegram.

## What to cut

Act on one sighting for the staging tells. The rhythm and vocabulary tells count when they pile up, or when they are on this list.

**Staging.** "Not X but Y", including the same contrast split across two sentences. A one-line closer that restates the line before it. "At its core", "the real question", "what really matters". "Here's the thing", "let's break this down". "This isn't about", "to be clear", answering an objection nobody made.

**Rhythm.** Three items or three identical sentence shapes when the meaning does not have three parts. The same "Expect X. Plan Y." cadence on every MissionsGui row. Dashes used to avoid deciding how two clauses relate.

**Inflation.** crucial, pivotal, robust, seamless, leverage, utilize, delve, underscore, testament, landscape (as an abstraction), showcase, enhance, tapestry, enabler, "plays a key role", "setting the stage". Shallow riders: ensuring, highlighting, fostering, reflecting, showcasing. "Serves as / stands as / boasts" when "is" or "has" will do. Empty stakes: "threatens stability", "prevent further escalation", "local support erodes", "freedom of movement", unless the source names the road, the town, or the force.

**Brochure.** "Explore the base", "over 16 missions supported out of the box", "positive and coherent experience", "high-value enablers that carry significant responsibility".

**Leftovers.** Chat wrappers, "this section will explain", a heading repeated as the first sentence.

**Substitutions when the word carries no extra fact.** in order to → to. prior to → before. ensure → an imperative, or "make sure that". allows you to / enables you to → the action itself. and/or → one of them, or "X, or Y, or both".

A contrast stays when both halves tell the player something they would not assume. A list of three stays when there are three real items.

## Facts

Keep every claim the source supports. Do not add a name, number, grid, faction intent, casualty, or citation. If a sentence needs a detail you do not have, ask or write the shorter sentence. Do not invent a joke, a mistake, or a personality to sound human. Do not publish a guessed number as if the mission stated it.

## How to run a pass

1. List each string you will touch: file, then variable or array key. When the same line regenerates, edit the pool or template in `MissionLore.sqf` rather than one mission script.
2. Classify each string: order, intel, or base flavour.
3. Rewrite in that register. Change structure when the point is buried. Do not patch one banned word and leave the sentence shaped the same way.
4. Check the draft:
   - An order sentence much past 20 words, or an intel sentence much past 25, gets split.
   - Search for the staging tells, the dashes, and the word list above.
   - The opening says what to do, or what the situation is. The next sentence adds a fact, a consequence, or the next step.
   - Slots, tags, HTML, and grids are intact. No verb was swapped for variety. No gameplay number changed.
5. Deliver.
   - **Pasted text:** the final copy, then up to five notes: what changed, and any claim you could not verify.
   - **Files:** write only the final strings. Then a short summary of which files changed and what the voice change was.

After a file pass, search the touched files for: crucial, pivotal, robust, seamless, leverage, utilize, delve, underscore, testament, enabler, escalation, stability, freedom of movement, it's not, not just, ensuring, highlighting, fostering, serves as, stands as.

## Examples

### Rotary note (`Briefing.sqf`)

Before:

> Rotary-wing assets are high-value enablers that carry significant responsibility. ... supports a positive and coherent experience for ground forces and other players.

After:

> Rotary aircraft change the fight quickly and kill people when flown poorly. Treat the seat as earned: practice outside the mission so in-session flying is predictable for the ground force. The list below is the minimum bar.

### Lore stakes (`MissionLore.sqf`)

Before: "before local support erodes" / "prevent further escalation" / "deny the enemy freedom of movement"

After: "before they dig in" / "before they push further" / "before they move freely on that road"

### Lobby overview

Before: a feature list ("Explore the base... over 16 missions...").

After: one sentence for what, who, and where, then where to click (Rhodesy's office, then Manage Scenario / Missions). Detail stays in the Diary, not the first screen.

## When to use this

- The user asks to optimise, humanize, de-slop, or simplify blurbs, briefs, lore, diary, welcome text, or civilian lines.
- You are about to add a mission-type blurb, lore bundle, diary paragraph, or task description. Write it in this register the first time.
- You are editing string content in a file in the scope table.
