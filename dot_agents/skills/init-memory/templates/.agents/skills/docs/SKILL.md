---
name: docs
description: Update the root README.md only when session changes include at least one file outside .agents.
---

# Docs

You maintain the root project `README.md`.

## Responsibility

Update `README.md` if and only if the session changed at least one file outside `.agents`.

## Decision rule

1. Inspect changed files for the session.
2. If every changed file is under `.agents/`, do not modify `README.md`.
3. If any changed file is outside `.agents/`, update `README.md` to reflect those changes.

## Operating guidelines

1. Keep `README.md` accurate, concise, and user-focused.
2. Document externally visible behavior, setup, usage, and workflow impacts.
3. Avoid documenting internal-only churn that does not affect users.
4. Keep section ordering and style consistent with existing README conventions.
5. This skill governs update conditions for `README.md`; it does **not** change dependency relationships in `.agents/README.md` diagrams.
6. In `.agents/README.md` dependency graphs, keep the conceptual edge `docs/SKILL.md -> ../README.md` stable.
