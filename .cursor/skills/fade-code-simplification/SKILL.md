---
name: fade-code-simplification
description: >-
  Simplifies FADE SQF for clarity while preserving behavior. Use when refactoring
  .sqf that already works but is hard to follow, after a feature lands, when nested
  mission logic or duplicated spawn, hint, or task code should be cleaned up, or
  when the user asks to simplify, clean up, or reduce complexity. Do not use for
  feature work or bug fixes.
---

# FADE code simplification

Simplify SQF so the next edit is easier to read. Keep behavior identical: inputs, outputs, side effects, order, and multiplayer locality.

Process adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) `code-simplification` (MIT).

## When to stop

- The code is already consistent with its neighbors.
- You cannot yet say why the code exists.
- The change would alter spawn, AI, tasks, markers, or who executes a function.
- The user asked for a feature or a bug fix. Finish that first. Simplify in a separate pass only if they ask.

## Before editing

Read `agent-docs/AGENTS.md` and the surrounding function. Match this mission, not a generic style guide.

Answer before deleting or inlining anything:

- What is this responsible for, and who calls it?
- Does it run on the server, a client, or both?
- Is the awkward shape a locality rule, a JIP `publicVariable`, or a `remoteExec` target?
- Which suite case, if any, pins the current behavior?

If those answers are missing, read more. Do not simplify yet.

## Keep these

| Shape | Why it stays |
|-------|----------------|
| `FADE_*` server/mission/world, `FAC_*` client GUI | Project split |
| Locals `_grp`, `_pos`, `_veh`, `_unit`, `_args` | Normal SQF in this repo |
| Long phase functions in a mission runner | One phase, one function. Length alone is not a split |
| `if (!isServer) exitWith {}` | Server authority |
| `remoteExec [..., 2]` and `remoteExec [..., _player]` | Target is the behavior |
| `publicVariable` on RPC entry points | Clients and JIP call them by name |
| `[[_args...], _fallback] call FADE_findSafePosArray` | Do not inline `BIS_fnc_findSafePos` |
| `(call FADE_missionRun_getContext) params [...]` | Runners must not read `FADE_missionRun_*` inline |
| `diag_log` tags such as `[FAC ...]` | Headless and RPT triage depend on them |

## Change

- Deep `if` stacks: `exitWith` guards, then the work.
- The same spawn, hint, marker, or task block copied across runners: call an existing helper. Add a new helper in the same file only when none exists.
- Names that lie (`get*` that creates a group): rename to the real verb.
- Commented-out blocks and unused locals: remove after confirming nothing calls them.
- Comments that restate the next line: delete. Comments that explain locality or a mod quirk: keep.

One simplification at a time. Stay inside the files this task already touches.

## Verify

After each edit, from the mission folder:

```powershell
powershell -ExecutionPolicy Bypass -File ..\tools\sqfvm\Invoke-FadeSqfLint.ps1
```

After the whole pass, if behavior is server-side, run headless compile once. Commands and RPT markers: [fade-headless-test](../fade-headless-test/SKILL.md). Do not boot the dedicated server after every small edit.

- Lint passes.
- Existing suite cases still pass without edits to the tests.
- No `remoteExec` target, `isServer` guard, or `publicVariable` was removed.
- The diff is the simplification only.

Do not commit unless the user asks.

## Rationalizations

| Excuse | Response |
|--------|----------|
| Fewer lines is simpler | A dense one-liner is worse than a short guard chain |
| This 80-line phase should be five helpers | Split only when the block has a second caller or a second responsibility |
| Those short locals are unclear | Renaming `_pos` to `_missionPosition` fights the file around it |
| This wrapper does nothing | Check locality and RPC before inlining |
| I can simplify the next file while I am here | Stay in scope |
| The suite is slow, so skip it | Lint each edit. Run compile once at the end of a server-side pass |
