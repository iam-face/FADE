---
name: update-fade-github
description: Commit and push FADE to GitHub (iam-face/FADE). Day-to-day work stays on beta until the user asks to merge it into main. Both branches contain the Altis and Stratis missions. Use when user asks to push/sync/update the repo.
disable-model-invocation: true
---

# Update FADE GitHub

Sync **https://github.com/iam-face/FADE.git**. `main` is the central branch. `beta` is the development branch. Both contain the Altis and Stratis missions. Day-to-day checkout is `beta`. Commit and push `beta` until the user asks to merge `beta` into `main`. Invocation = permission to commit+push unless user says dry-run or commit-only.

## Safety

Never: change git config, force-push, hard-reset, skip hooks, commit secrets. Respect `.gitignore` (`.cursor/agent-docs/`, `local_server/`, `*.bat`, `*.py`). Amend only if user asks and commit unpushed.

## Workflow (PowerShell: use `;` not `&&`)

1. **Inspect:** `git status -sb`, `git diff --stat HEAD`, `git log --oneline -3`. Clean + synced → report up to date, stop.
2. **Stage:** `git add -A`; review for secrets/huge binaries.
3. **Commit:** 1-line subject (+ optional bullets); match repo style (`Beta N:`, `fix:`, `feat:`).
4. **Push:** `git push origin HEAD`. Ongoing work pushes `beta`. Push `main` only for a requested merge.
5. **Verify:** `git status -sb`, `git log -1 --oneline`

## Failures

- Non-fast-forward: `git fetch`; compare branches; no force-push without user approval.
- Hook fail: fix + **new** commit.
- Auth fail: user signs in; no tokens in repo.

Variants: **dry-run** (inspect + proposed message only), **commit-only**, **push-only** (already committed).
