---
name: init-memory
description: Initialize a project-local .agents memory workspace and a basic AGENTS.md using reusable templates.
---

# Init Memory

Use this skill when the user asks to bootstrap project memory scaffolding.

This skill creates a project-local `.agents` workspace modeled on `~/projects/cr3-keywords/.agents`, with these intentional exclusions:

- no `zed-threads` skill
- no `shell-completions` skill

## Files managed by this skill

- `.agents/README.md`
- `.agents/memory.md`
- `.agents/active_context.md`
- `.agents/decisions.md`
- `.agents/failures.md`
- `.agents/skills/ai-janitor/SKILL.md`
- `.agents/skills/docs/SKILL.md`
- `.agents/skills/end-session/SKILL.md`
- `.agents/skills/memento/SKILL.md`
- `.agents/skills/start-session/SKILL.md`
- `.agents/skills/tests/SKILL.md`
- `.agents/skills/theory-of-mind/SKILL.md`
- `AGENTS.md` (basic project guidance)

## Procedure

1. Create `.agents` and `.agents/skills` if they do not exist.
2. For each managed file:
   - If the file is missing, copy it from this skill's templates.
   - If the file already exists, do not overwrite unless the user explicitly asks.
3. Use these template sources:
   - `templates/.agents/*` -> `.agents/*`
   - `templates/AGENTS.md` -> `AGENTS.md`
4. Confirm exclusions:
   - Do not create `.agents/skills/zed-threads`.
   - Do not create `.agents/skills/shell-completions`.
5. After scaffolding, summarize which files were created and which were skipped because they already existed.
