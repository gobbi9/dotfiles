---
name: commit-push
description: Generate a commit message from the current diff, let the user edit/verify it in $env.EDITOR, then commit and push the current branch while respecting 1Password biometric auth requirements.
---

# Commit and push current branch

Use this skill when the user asks to commit current changes and push the active git branch.

## Required behavior

- Generate the commit message from the actual git diff content.
- Use an explicit commit message format:
  - First line (header): `Add|Update|Fix|Remove|Refactor <short description>`.
  - Header must be no more than 80 characters.
  - Then add exactly two newline characters.
  - For non-trivial changes, add a bullet list describing what changed and why.
- Let the user edit/verify the generated message in `$env.EDITOR` before committing.
- Never set `GIT_EDITOR=true`, `EDITOR=true`, or any other editor-bypass flag for this workflow.
- If commit opens an editor and waits for user interaction, allow it to wait (do not force non-interactive mode).
- Commit and push the current branch only after message confirmation.
- Commit and push require 1Password biometric authentication in this environment.
- If 1Password authentication fails at any step, stop immediately.
- Do **not** retry with alternative auth methods and do **not** attempt to bypass authentication.

## Workflow

1. Inspect current repository state:
   - `git --no-pager status --short`
   - `git --no-pager diff --stat`
2. Stage all current changes before committing:
   - `git add -A`
3. Read staged diff and produce a concise commit message reflecting the actual changes:
   - `git --no-pager diff --cached`
   - Build the message with this structure:
     - Line 1: `Add|Update|Fix|Remove|Refactor <short description>` (max 80 chars).
     - Then exactly two newline characters.
     - For non-trivial changes, include bullets like `- <change>: <reason/impact>`.
4. Open commit editor with the generated message prefilled:
   - Run `git commit --edit -m "<generated message>"`.
   - This lets the user review/edit before the commit is finalized.
   - Use the editor configured via `$env.EDITOR`.
   - Do **not** prefix commit commands with `GIT_EDITOR=true`, `EDITOR=true`, or similar non-interactive overrides.
   - If the command waits for editor input, let it wait until the user finishes editing.
5. If the user saves an empty commit message, stop immediately:
   - Git will abort the commit.
   - Do not push.
6. Determine current branch:
   - `git branch --show-current`
7. Push current branch:
   - First try `git push`.
   - If push fails only because upstream is missing, run `git push --set-upstream origin <current-branch>`.

## Failure handling

- If there are no changes to commit, report that and stop.
- If the user saves an empty commit message, report that commit was aborted and stop without push.
- If commit fails due to auth/biometric prompt failure, stop and report it.
- If push fails due to auth/biometric prompt failure, stop and report it.
- Do not perform fallback auth flows, credential rewrites, remote URL rewrites, or other workarounds.
