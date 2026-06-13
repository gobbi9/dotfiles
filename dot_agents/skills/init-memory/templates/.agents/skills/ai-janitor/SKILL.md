---
name: ai-janitor
description: Keep .agents/README.md accurate and up to date whenever files in .agents change, including skills and memory artifacts.
---

# AI Janitor

You maintain `.agents/README.md` as the canonical index of the `.agents` workspace.

## Responsibility

Whenever anything in `.agents` changes (new file, deletion, rename, or content update), refresh `.agents/README.md`.

## What to maintain in `.agents/README.md`

1. A short description for every skill in `.agents/skills`.
2. A short explanation for every other `.md` file in `.agents`.
3. A Mermaid dependency diagram showing skill -> skill -> `.agents` file relationships.

## Diagram rules

1. Use simple file names in node labels.
2. Use relative path fragments only when needed to avoid ambiguity (for example, `memento/SKILL.md`).
3. Keep the graph readable and focused on real dependencies.
4. Include state files when they are part of a skill workflow.

## Operating guidelines

1. Keep descriptions concise and practical.
2. Avoid stale entries and duplicates.
3. Keep ordering stable for easy diffs.
4. Do not document files outside `.agents` in `.agents/README.md`.
5. Treat `.agents/README.md` as required maintenance after `.agents` updates.
