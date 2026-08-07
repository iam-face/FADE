---
name: update-fade-github
description: Commit and push FADE to GitHub (iam-face/FADE, main). Use when user asks to push/sync/update the repo.
disable-model-invocation: true
---

# Update FADE GitHub

Sync workspace → **https://github.com/iam-face/FADE.git** branch **`main`**. Invocation = permission to commit+push unless user says dry-run or commit-only.

## Safety

Never: change git config, force-push, hard-reset, skip hooks, commit secrets. Respect `.gitignore` (`.cursor/agent-docs/`, `local_server/`, `*.bat`, `*.py`). Amend only if user asks and commit unpushed.

## Workflow (PowerShell: use `;` not `&&`)

1. **Inspect:** `git status -sb`, `git diff --stat HEAD`, `git log --oneline -3`. Clean + synced → report up to date, stop.
2. **Stage:** `git add -A`; review for secrets/huge binaries.
3. **Commit:** 1-line subject (+ optional bullets); match repo style (`Beta N:`, `fix:`, `feat:`).
4. **Push:** `git push origin main`
5. **Verify:** `git status -sb`, `git log origin/main -1`

## Failures

- Non-fast-forward: `git fetch`; compare branches; no force-push without user approval.
- Hook fail: fix + **new** commit.
- Auth fail: user signs in; no tokens in repo.

Variants: **dry-run** (inspect + proposed message only), **commit-only**, **push-only** (already committed).
