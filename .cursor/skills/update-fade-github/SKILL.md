---
name: update-fade-github
description: Commit and push the current FADE branch to GitHub (iam-face/FADE). main is the central branch. beta is the development branch. Both contain the Altis and Stratis missions. Use when user asks to push/sync/update the repo.
disable-model-invocation: true
---

# Update FADE GitHub

Sync the current checkout to **https://github.com/iam-face/FADE.git**. GitHub branches are `main` (central; both missions) and `beta` (development; both missions). Push the current branch. Invocation = permission to commit+push unless user says dry-run or commit-only.

## Safety

Never: change git config, force-push, hard-reset, skip hooks, commit secrets. Respect `.gitignore` (`.cursor/agent-docs/`, `local_server/`, `*.bat`, `*.py`). Amend only if user asks and commit unpushed.

## Workflow (PowerShell: use `;` not `&&`)

1. **Inspect:** `git status -sb`, `git diff --stat HEAD`, `git log --oneline -3`. Clean + synced → report up to date, stop.
2. **Stage:** `git add -A`; review for secrets/huge binaries.
3. **Commit:** 1-line subject (+ optional bullets); match repo style (`Beta N:`, `fix:`, `feat:`).
4. **Push:** `git push origin HEAD` (the current branch: `main` or `beta`).
5. **Verify:** `git status -sb`, `git log -1 --oneline`

## Failures

- Non-fast-forward: `git fetch`; compare branches; no force-push without user approval.
- Hook fail: fix + **new** commit.
- Auth fail: user signs in; no tokens in repo.

Variants: **dry-run** (inspect + proposed message only), **commit-only**, **push-only** (already committed).
